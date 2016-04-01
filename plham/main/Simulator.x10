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
	 * @param json  a JSON object, or properties of fundamentals
	 * @param list  a list of markets they belong to this fundamentals
	 * @return a fundamentals
	 */
	public def createFundamentals(json:JSON.Value, list:JSON.Value):Fundamentals {
		val table = new HashMap[String,Long]();

		val graph = JSONUtils.getDependencyGraph(CONFIG, list, "markets");
		val nodes = new ArrayList[String]();
		for (name in graph.keySet()) {
			if (!CONFIG(name)("class").equals("MarketGroup")) {
				val i = nodes.size();
				table(name) = i;
				nodes.add(name);
			}
		}

		val random = new JSONRandom(RANDOM);

		val N = nodes.size();
		val f = new Fundamentals(RANDOM, table, N);

		for (i in 0..(N - 1)) {
			val name = nodes(i);
			f.setInitial(name, random.nextRandom(CONFIG(name)(["fundamentalPrice", "marketPrice"])));
		}
		for (i in 0..(N - 1)) {
			val name = nodes(i);
			f.setDrift(name, random.nextRandom(CONFIG(name)("fundamentalDrift", "0.0")));
		}
		for (i in 0..(N - 1)) {
			val name = nodes(i);
			f.setVolatility(name, random.nextRandom(CONFIG(name)("fundamentalVolatility", "0.0")));
		}
		if (json.has("pairwise")) {
			val edges = json("pairwise");
			for (k in 0..(edges.size() - 1)) {
				val triple = edges(k);
				val iname = triple(0).toString();
				val jname = triple(1).toString();
				f.setCorrelation(iname, jname, random.nextRandom(triple(2)));
			}
		}
		for (i in 0..(N - 1)) {
			val name = nodes(i);
			f.setCorrelation(name, name, 1.0);
		}
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
}
