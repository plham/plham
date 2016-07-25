package plham.main;
import x10.io.File;
import x10.util.ArrayList;
import x10.util.HashMap;
import x10.util.List;
import x10.util.Random;
import x10.util.Map;
import plham.Agent;
import plham.Env;
import plham.Event;
import plham.Fundamentals;
import plham.HighFrequencyAgent;
import plham.IndexMarket;
import plham.Market;
import plham.Order;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.util.JSONUtils;

/**
 * A base class for simulation models.
 * See {@link plham.main.Runner} for execution models.
 * See the subclass {@link plham.Main} for the core methods.
 */
public abstract class Simulator extends Env {

	/** It stores the return values of <code>createMarkets()</code>, <code>createAgents()</code>, and <code>createEvents()</code>. */
	public var GLOBAL:Map[String,Any];
	/** The JSON config file. */
	public var CONFIG:JSON.Value;
	/** The root of all instances of Random. */
	public var RANDOM:Random;

	/**
	 * Get the root of all instances of Random (allowed to call only at the place 0).
	 * @return the root
	 */
	public def getRandom():Random {
		assert here.id == 0 : "getRandom() must be called at Place(0)";
		return RANDOM;
	}

	public abstract def beginSimulation():void;

	public abstract def endSimulation():void;

	public abstract def beginSession(sessionName:String):void;

	public abstract def endSession(sessionName:String):void;

	public abstract def print(sessionName:String):void;

	/**
	 * For the item grouping technology based on the idea of <q>keyword chain</q> in JSON.
	 * @param json
	 * @param className  a dummy class name, e.g., "AgentGroup"
	 * @param keyword  a name for keyword chain, e.g., "agents"
	 * @return a list of items
	 */
	protected def createItemGroup[T](json:JSON.Value, className:String, keyword:String):List[T] {
		val items = new ArrayList[T]();
		if (json("class").equals(className)) { // A dummy class
			val list = json(keyword);
			for (i in 0..(list.size() - 1)) {
				val name = list(i).toString();
				items.addAll(GLOBAL(name) as List[T]); // SEE: getDependencySortedList()
			}
		}
		return items;
	}

	public def createAllMarkets(list:JSON.Value):List[Market] {
		val allMarkets = new ArrayList[Market]();
		var id:Long = 0;
		val sorted = JSONUtils.getDependencySortedList(CONFIG, list, "markets");
		for (i in 0..(sorted.size() - 1)) {
			val name = sorted(i).toString();
			val markets:List[Market];
			if (CONFIG(name)("class").equals("MarketGroup")) {
				markets = createItemGroup[Market](CONFIG(name), "MarketGroup", "markets");
			} else {
				markets = createMarkets(CONFIG(name));
				for (m in markets) {
					m.setId(id++);
					m.setName(name);
					m.setRandom(getRandom().split());
				}
				allMarkets.addAll(markets);
			}
			GLOBAL(name) = markets as Any;
		}
		return allMarkets;
	}

	public abstract def createMarkets(json:JSON.Value):List[Market];

	public def createAllAgents(list:JSON.Value):List[Agent] {
		val allAgents = new ArrayList[Agent]();
		var id:Long = 0;
		val sorted = JSONUtils.getDependencySortedList(CONFIG, list, "agents");
		for (i in 0..(sorted.size() - 1)) {
			val name = sorted(i).toString();
			val agents:List[Agent];
			if (CONFIG(name)("class").equals("AgentGroup")) {
				agents = createItemGroup[Agent](CONFIG(name), "AgentGroup", "agents");
			} else {
				agents = createAgents(CONFIG(name));
				for (a in agents) {
					a.setId(id++);
					a.setName(name);
					a.setRandom(getRandom().split());
				}
				allAgents.addAll(agents);
			}
			GLOBAL(name) = agents as Any;
		}
		return allAgents;
	}

	public abstract def createAgents(json:JSON.Value):List[Agent];

	public def createAllEvents(list:JSON.Value):List[Event] {
		val allEvents = new ArrayList[Event]();
		for (i in 0..(list.size() - 1)) {
			val name = list(i).toString();
			val events:List[Event];
			if (CONFIG(name)("class").equals("EventGroup")) {
				events = createItemGroup[Event](CONFIG(name), "EventGroup", "events");
			} else {
				events = createEvents(CONFIG(name));
//				for (e in events) {
//					e.setId(id++);
//					e.setName(name);
//					e.setRandom(getRandom().split());
//				}
			}
			allEvents.addAll(events);
			GLOBAL(name) = events as Any;
		}
		return allEvents;
	}

	public abstract def createEvents(json:JSON.Value):List[Event];

	/**
	 * Create an instance of Fundamentals based on the JSON object.
	 * @param markets
	 * @param json  a JSON object, or properties of correlations of fundamentals
	 * @return a fundamentals
	 */
	public def createFundamentals(markets:List[Market], json:JSON.Value):Fundamentals {
		val random = new JSONRandom(RANDOM);

		val N = markets.size();
		val f = new Fundamentals(RANDOM);

		for (i in 0..(N - 1)) {
			val m = markets(i);
			f.setInitial(m, random.nextRandom(CONFIG(m.name)(["fundamentalPrice", "marketPrice"])));
		}
		for (i in 0..(N - 1)) {
			val m = markets(i);
			f.setDrift(m, random.nextRandom(CONFIG(m.name)("fundamentalDrift", "0.0")));
		}
		for (i in 0..(N - 1)) {
			val m = markets(i);
			f.setVolatility(m, random.nextRandom(CONFIG(m.name)("fundamentalVolatility", "0.0")));
		}
		if (json.has("pairwise")) {
			val edges = json("pairwise");
			for (k in 0..(edges.size() - 1)) {
				val triple = edges(k);
				val mi = getItemByName[Market](triple(0));
				val mj = getItemByName[Market](triple(1));
				f.setCorrelation(mi, mj, random.nextRandom(triple(2)));
			}
		}
		for (i in 0..(N - 1)) {
			val m = markets(i);
			f.setCorrelation(m, m, 1.0);
		}
		
		f.setup(); // MAKE SURE to call this.

		return f;
	}

	/** For system use only. */
	public def updateFundamentals(f:Fundamentals) {
		f.update();
	}

	/** For system use only. */
	public def updateMarketsUsingFundamentalPrice(markets:List[Market], fundamentals:Fundamentals) {
		for (market in markets) {
			var nextFundamental:Double = fundamentals.get(market);
			if (market instanceof IndexMarket) { // Remove this.
				nextFundamental = (market as IndexMarket).getFundamentalIndex();
			}
			market.updateMarketPrice(nextFundamental);
			market.updateFundamentalPrice(nextFundamental);
			market.updateOrderBooks();
		}
	}

	/** For system use only. */
	public def updateMarketsUsingMarketPrice(markets:List[Market], fundamentals:Fundamentals) {
		for (market in markets) {
			var nextFundamental:Double = fundamentals.get(market);
			if (market instanceof IndexMarket) { // Remove this.
				nextFundamental = (market as IndexMarket).getFundamentalIndex();
			}
			market.updateMarketPrice();
			market.updateFundamentalPrice(nextFundamental);
			market.updateOrderBooks();
		}
	}

	/**
	 * Get a list of items (instances) stored in GLOBAL by the name.
	 * @param name  a section name defined in the JSON config file.
	 * @return a list of instances having the name.
	 */
	public def getItemsByName[T](name:String):List[T] {
		return GLOBAL(name) as List[T];
	}

	/**
	 * Get an item (instance) stored in GLOBAL by the name.
	 * Since in GLOBAL even a single item is stored as <code>List</code>, the size must be 1.
	 * This throws an exception if the size is &gt; 1.
	 * @param name  a section name defined in the JSON config file.
	 * @return an instance having the name.
	 */
	public def getItemByName[T](name:String):T {
		val items = getItemsByName[T](name);
		assert items.size() == 1 : "getItemByName() got more than one object";
		return items(0);
	}

	/**
	 * Get a list of items (instances) stored in GLOBAL specified by the list of names.
	 * @param names  section names defined in the JSON config file.
	 * @param n  the length of names.
	 * @return a list of instances having the names.
	 */
	public def getItemsByName[T](names:(i:Long)=>String, n:Long):List[T] {
		val items = new ArrayList[T]();
		for (i in 0..(n - 1)) {
			items.addAll(getItemsByName[T](names(i)));
		}
		return items;
	}

	/**
	 * Get a list of items (instances) stored in GLOBAL specified by the list of names.
	 * @param json  section name(s) (String or List) defined in the JSON config file.
	 * @return a list of instances having the name(s).
	 */
	public def getItemsByName[T](json:JSON.Value):List[T] {
		if (json.isList()) {
			return getItemsByName[T]((i:Long) => json(i).toString(), json.size());
		}
		return getItemsByName[T](json.toString());
	}

	/**
	 * Get an item (instance) stored in GLOBAL by the name.
	 * Since in GLOBAL even a single item is stored as <code>List</code>, the size must be 1.
	 * This throws an exception if the size is &gt; 1.
	 * @param json  a section name (String or List) defined in the JSON config file.
	 * @return an instance having the name.
	 */
	public def getItemByName[T](json:JSON.Value):T {
		val items = getItemsByName[T](json);
		assert items.size() == 1 : "getItemByName() got more than one object";
		return items(0);
	}
}
