package plham.main;
import x10.io.File;
import x10.util.ArrayList;
import x10.util.HashMap;
import x10.util.Indexed;
import x10.util.List;
import x10.util.NoSuchElementException;
import x10.util.Random;
import x10.util.Map;
import plham.agent.FCNAgent;
import plham.Agent;
import plham.Env;
import plham.Event;
import plham.Fundamentals;
import plham.HighFrequencyAgent;
import plham.IndexMarket;
import plham.Market;
import plham.Order;
import plham.util.DistAllocManager;
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
    public var marketName2Ranges:Map[String,List[LongRange]];
	/** The JSON config file. */
	public var CONFIG:JSON.Value;
	/** The root of all instances of Random. */
	public var RANDOM:Random;

	private val agentInitializers:HashMap[String, AgentsInitializer];
	private val agentGenerators:HashMap[String, AgentGenerator];
	private val marketInitializers:HashMap[String, MarketsInitializer];
	private val marketGenerators:HashMap[String, MarketGenerator];
	private val eventInitializers:HashMap[String, EventInitializer];
	private val eventGenerators:HashMap[String, EventGenerator];

	/** The type of functions which create and initialize agents.
	 *  Agent-initializers must take (name:String, randoms:Indexed[Random], range:LongRange, config:JSON.Value, container:Settable[Long, Agent]).
	 *  For each 'id' in a given 'range', initializers must create an agent and initialize it using 'name', 'randoms(id)', 'config', then set 
	 *  the agent on 'container(id)'.
	 *  @param name
	 *    A name of agents the initializer creates and initializes. All the agents which initializers create and initialize at a time have the same name.
	 *  @param randoms
	 *    Pseudo random number generators for each agents. A agent whose id is k must use randoms(k).
	 *  @param range
	 *    Range of ids which the initializer creates.
	 *  @param config
	 *    A config for agents.
	 *  @param container
	 *    A container of agents. Initialized agents are set to it. An agent whose id is k is set to container(k).
	 */
	public static type AgentsInitializer = (String, Indexed[Random], LongRange, JSON.Value, Settable[Long, Agent])=>void;
	public static type AgentInitializer = (Long, String, Random, JSON.Value)=>Agent;
	/** The type of functions which generate agents' config(json value) from json value. */
	public static type AgentGenerator = (JSON.Value)=>List[JSON.Value];
	public static type MarketInitializer = (Long, String, Random, JSON.Value)=>Market;
	public static type MarketsInitializer = (Long, String, Random, JSON.Value)=>List[Market];
	public static type MarketGenerator = (JSON.Value)=>List[JSON.Value];
	public static type EventInitializer = (Long, String, Random, JSON.Value)=>Event;
	public static type EventGenerator = (JSON.Value)=>List[JSON.Value];

	public def this() {
		agentInitializers = new HashMap[String, AgentsInitializer]();
		agentGenerators = new HashMap[String, AgentGenerator]();
		marketInitializers = new HashMap[String, MarketsInitializer]();
		marketGenerators = new HashMap[String, MarketGenerator]();
		eventInitializers = new HashMap[String, EventInitializer]();
		eventGenerators = new HashMap[String, EventGenerator]();
	}

	/**
	 * Adds AgentsInitailizer that initializes all agents specified in a json-config element.
	 * For example, if the json-config file is 
	 *		...
	 *		"SomeAgentsForMarket-X": {
	 *			"class": "SomeAgent",
	 *			"numAgents": 100,
	 *			...
	 *		}
	 *		...
	 * , then AgentsInitializer must initialize all the 100 agents.
	 * If you want to initialize the 100 agents in a same way, you can use Simulator#addAgentInitializer.
	 */
	public def addAgentsInitializer(name:String, initializer:AgentsInitializer) {
		agentInitializers.put(name, initializer);
	}

	/**
	 * Adds one agent initializer to the simulator. This method creates AgentsInitializer from specified AgentInitializer, and adds it.
	 */
	public def addAgentInitializer(name:String, initializer:AgentInitializer) {
		agentInitializers.put(name, (name:String, randoms:Indexed[Random], idRange:LongRange, config:JSON.Value, container:Settable[Long, Agent]) => {
			for (id in idRange) {
				container(id) = initializer(id, name, randoms(id), config);
			}
		});
	}

	public def addAgentGenerator(name:String, generator:AgentGenerator) {
		agentGenerators.put(name, generator);
	}

	public def addMarketInitializer(name:String, initializer:MarketInitializer) {
		this.addMarketsInitializer(name, (id:Long, name:String, random:Random, json:JSON.Value) => {
			val numMarkets = json.has("numMarkets") ? json("numMarkets").toLong() : 1;
			val markets = new ArrayList[Market](numMarkets) as List[Market];
			markets.add(initializer(id, name, random, json));
			this.GLOBAL(markets(0).name) = markets as Any; // assuming 'numMarkets' is always set to 1.
			return markets;
		});
	}

	public def addMarketsInitializer(name:String, initializer:MarketsInitializer) {
		marketInitializers.put(name, initializer);
	}

	public def addMarketGenerator(name:String, generator:MarketGenerator) {
		marketGenerators.put(name, generator);
	}

	public def addEventInitializer(name:String, initializer:EventInitializer) = eventInitializers.put(name, initializer);
	public def addEventGenerator(name:String, generator:EventGenerator) = eventGenerators.put(name, generator);

	/**
	 * Get the root of all instances of Random (allowed to call only at the place 0).
	 * @return the root
	 */
	public def getRandom():Random {
		// assert here.id == 0 : "getRandom() must be called at Place(0)";
		return RANDOM;
	}

	public abstract def beginSimulation():void;

	public abstract def endSimulation():void;

	public abstract def beginSession(sessionName:String):void;

	public abstract def endSession(sessionName:String):void;

	public abstract def print(sessionName:String):void;

	public abstract def endprint(sessionName:String,iterationSteps:Long):void;

	/**
	 * For the item grouping technology based on the idea of <q>keyword chain</q> in JSON.
	 * @param json
	 * @param className  a dummy class name, e.g., "AgentGroup"
	 * @param keyword  a name for keyword chain, e.g., "agents"
	 * @return a list of items
	 */
	protected def createItemGroup[T](json:JSON.Value, className:String, keyword:String):List[T] {
		val items = new ArrayList[T]();
		//Console.OUT.println("#classname:"+json("class"));
		if (json("class").equals(className)) { // A dummy class
			val list = json(keyword);
			for (i in 0..(list.size() - 1)) {
				val name = list(i).toString();
				items.addAll(GLOBAL(name) as List[T]); // SEE: getDependencySortedList()
			}
		}
		return items;
	}

	private def fromRail[T](xs:Rail[T]):ArrayList[T] {
		val ret = new ArrayList[T](xs.size);
		for (i in xs.range()) {
			ret(i) = xs(i);
		}
		return ret;
	}

	public def createAllMarkets(list:JSON.Value):List[Market] {
		val allMarkets = new ArrayList[Market]();
		val keywords = fromRail(["requires" as String]);
		val sorted = JSONUtils.getDependencySortedList(CONFIG, list, keywords);
		// TODO tk hack
		this.markets = allMarkets;
		marketName2Ranges = new HashMap[String,List[LongRange]]();
		//Console.OUT.println("#createAllMarkets");
		for (i in 0..(sorted.size() - 1)) {
			val name = sorted(i).toString();
			val markets:List[Market];
			val config = CONFIG(name);
			val className = config("class").toString();
			//Console.OUT.println("#"+i+"."+name);
			if (config("class").equals("MarketGroup")) {
			    marketName2Ranges(name) = createItemGroup[LongRange](config, "MarketGroup", "markets");
			} else if (marketGenerators.containsKey(className)) { // it's a macro.
			    val before = allMarkets.size();
			    val generator = marketGenerators(className);
				markets = new ArrayList[Market]();
				for (configGenerated in generator(config)) {
				    val id = allMarkets.size() + markets.size();
					val marketName = configGenerated("name").toString();
					markets.addAll(createMarkets(id, marketName, getRandom().split(), configGenerated));
				}
				allMarkets.addAll(markets);
			    val after = allMarkets.size();
			    if(before!=after) {
				marketName2Ranges(name) = new ArrayList[LongRange]();
				marketName2Ranges(name).add(before..(after-1));
			    }
			} else {
			    val before = allMarkets.size();
				val json = CONFIG(name);
				val id = allMarkets.size();
				markets = createMarkets(id, name, getRandom().split(), json);
				allMarkets.addAll(markets);
			    val after = allMarkets.size();
			    if(before!=after) {
				marketName2Ranges(name) = new ArrayList[LongRange]();
				marketName2Ranges(name).add(before..(after-1));
			    }
			}
//Console.OUT.println("#MarketGroup " + name + "@ ranges:" + marketName2Ranges(name));
		}
		return allMarkets;
	}

	public def createMarkets(id:Long, name:String, random:Random, json:JSON.Value):List[Market] {
		val className = json("class").toString();
		val initializer = marketInitializers(className);
		assert initializer != null : "Initializer is not defined for class '" + className + "'";
		try {
			return initializer(id, name, random, json);
		} catch (e:Exception) {
			Console.ERR.println("An error occurred while creating " + name + ", from " + JSON.dump(json));
			throw e;
		}
	}

	public def createAllAgents(list:JSON.Value, dm:DistAllocManager[Agent]) {
		var id:Long = 0;
		val sorted = JSONUtils.getDependencySortedList(CONFIG, list, "agents");
		var numAllAgents:Long = 0;

		// create agent group referred in "AgentGroup"s.
		// and create agents' config by calling agent-generators(they're macros. ex:AgentsForEachMarkets)
		val configsGenerated = new HashMap[String, List[JSON.Value]]();
		// agents' configs generated by macros
		for (i in 0 .. (sorted.size() - 1)) {
			val name = sorted(i).toString();
			val config = CONFIG(name);
			val className = config("class").toString();
			if (className.equals("AgentGroup")) {
				//agents = createItemGroup[Agent](config, "AgentGroup", "agents");
				//GLOBAL(name) = agents as Any;
			} else if (agentGenerators.containsKey(className)) { // it's a macro.
				val generator = agentGenerators(className);
				assert (config.has("base")): " config does not has base ";
				configsGenerated(name) = generator(config);
			}
		}

		// count the number of agents to be created.
		for (i in 0 .. (sorted.size() - 1)) {
			val name = sorted(i).toString();
			val config = CONFIG(name);
			val className = config("class").toString();
			if (className.equals("AgentGroup") || agentGenerators.containsKey(className)) continue;
			numAllAgents += config("numAgents").toLong();
		}
		for (entry in configsGenerated.entries()) {
			for (config in entry.getValue()) {
				numAllAgents += config("numAgents").toLong();
			}
		}
		dm.setTotalCount(numAllAgents);
		var lastAgentId:Long = 0;
		val randoms = new plham.util.RandomSequenceBySplit(getRandom());
		for (i in 0 .. (sorted.size() - 1)) {
			val name = sorted(i).toString();
			val config = CONFIG(name);
			val className = config("class").toString();
			if (className.equals("AgentGroup") || agentGenerators.containsKey(className)) continue;
			val numAgents = config("numAgents").toLong();
			val range = new LongRange(lastAgentId, lastAgentId + numAgents - 1);
			lastAgentId += numAgents;
			val subList = dm.getRangedList(here, config, range);
			if(!subList.isEmpty()) createAgents(name, randoms, subList.getRange(), config, subList);
		}
		for (entry in configsGenerated.entries()) {
			val name = entry.getKey();
			val configs = entry.getValue();
			for (config in configs) {
				val className = config("class").toString();
				val numAgents = config("numAgents").toLong();
				val range = new LongRange(lastAgentId, lastAgentId + numAgents - 1);
				lastAgentId += numAgents;
				val subList = dm.getRangedList(here, config, range);
				if(!subList.isEmpty()) createAgents(name, randoms, subList.getRange(), config, subList);
			}
		}
		Console.OUT.println("# " + numAllAgents + " agents created.");
		return;
	}

	/* THIS METHOD IS OBSOLUTE. USE createAgents(String, Random, LongRange, JSON.Value, Settable[Long, AGent]). */
	public def createAgents(json:JSON.Value):List[Agent] {
		val className = json("class").toString();
		val initializer = agentInitializers(className);
		assert initializer != null : "Initializer is not defined for class '" + className + "'";
		assert(json.has("numAgents"));
		val numAgents = json("numAgents").toLong();
		val agents = new ArrayList[Agent](numAgents);
		val range = new LongRange(0, numAgents - 1);
		val name = "default";
		val randoms = new ArrayList[Random](numAgents);
		for (i in 0 .. (numAgents - 1)) {
			randoms(i) = getRandom().split();
		}
		initializer(name, randoms, range, json, agents);
		return agents;
	}

	public def createAgents(name:String, randoms:Indexed[Random], range:LongRange, json:JSON.Value, agents:Settable[Long, Agent]):void {
	try {
		val className = json("class").toString();
		val initializer = agentInitializers(className);
		assert initializer != null : "Initializer is not defined for class '" + className + "'";
		initializer(name, randoms, range, json, agents);
    } catch (e:Exception) { 
		Console.ERR.println("An error occurred while creating " + name + ", from " + JSON.dump(json));
		throw e;
	}

	}

	public def createAllEvents(list:JSON.Value):List[Event] {
		val allEvents = new ArrayList[Event]();
		var id:Long = 0;
		for (i in 0..(list.size() - 1)) {
			val name = list(i).toString();
			val events:List[Event];
			val className = CONFIG(name)("class").toString();
			if (className.equals("EventGroup")) {
				events = createItemGroup[Event](CONFIG(name), "EventGroup", "events");
			} else {
				assert eventInitializers.containsKey(className) : className + "'s initializer is not registered.";
				val initializer = eventInitializers(className);
				var ev:Event = null;
				try {
					ev = initializer(id++, name, this.getRandom().split(), CONFIG(name));
				} catch (e:Exception) {
					Console.ERR.println("An error occurred while creating " + name + ", from " + JSON.dump(CONFIG(name)));
					throw e;
				}
				events = new ArrayList[Event]();
				events.add(ev);
			}
			allEvents.addAll(events);
			GLOBAL(name) = events as Any;
		}
		return allEvents;
	}

	/**
	 * Override this to create events.
	 * @param json  a JSON object, or properties of events.
	 * @return a list of events.
	 */
	public def createEvents(json:JSON.Value):List[Event] {
		assert false : "createEvents is not defined in the Simulator class.";
		return new ArrayList[Event]();
	}

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
			var initialPrice:Double = 0;
			try {
				initialPrice = m.getInitialFundamentalPrice();
			} catch (e:NoSuchElementException) {
				try {
					initialPrice = m.getInitialMarketPrice();
				} catch (e2:NoSuchElementException) {
					assert false : "there's no initial fundamental or market price definition in config.";
				}
			}
			f.setInitial(m, initialPrice);
		}
		for (i in 0..(N - 1)) {
			val m = markets(i);
			f.setDrift(m, 0.0);
			// (5/31, matsuura) commented out the line below. "fundamentalDrift" never appeared in config files, nor in x10 sources currently.
			// f.setDrift(m, random.nextRandom(CONFIG(m.name)("fundamentalDrift", "0.0")));
		}
		for (i in 0..(N - 1)) {
			val m = markets(i);
			f.setVolatility(m, m.getFundamentalVolatility());
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
			if (market instanceof IndexMarket) {
				market.updateMarketPrice(market.getFundamentalPrice());
			} else {
				var nextFundamental:Double = fundamentals.get(market);
				market.updateMarketPrice(nextFundamental);
				market.updateFundamentalPrice(nextFundamental);
			}
			market.updateOrderBooks();
		}
	}

	/** For system use only. */
	public def updateMarketsUsingMarketPrice(markets:List[Market], fundamentals:Fundamentals) {
		for (market in markets) {
			market.updateMarketPrice();
			if (! (market instanceof IndexMarket)) {
				// index markets need not updated fundamentals. they calculates fundamental price from the underlyings on the fly.
				var nextFundamental:Double = fundamentals.get(market);
				market.updateFundamentalPrice(nextFundamental);
			}
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


	/**
	 * Get a list of items (instances) stored in GLOBAL by the name.
	 * @param name  a section name defined in the JSON config file.
	 * @return a list of instances having the name.
	 */
    public def getItemsByName0[T](kv:Map[String,List[T]], name:String):List[T] {
		return kv(name) as List[T];
	}

	/**
	 * Get an item (instance) stored in GLOBAL by the name.
	 * Since in GLOBAL even a single item is stored as <code>List</code>, the size must be 1.
	 * This throws an exception if the size is &gt; 1.
	 * @param name  a section name defined in the JSON config file.
	 * @return an instance having the name.
	 */
	public def getItemByName0[T](kv:Map[String,List[T]], name:String):T {
		val items = getItemsByName0[T](kv, name);
		assert items.size() == 1 : "getItemByName0() got more than one object";
		return items(0);
	}

	/**
	 * Get a list of items (instances) stored in GLOBAL specified by the list of names.
	 * @param names  section names defined in the JSON config file.
	 * @param n  the length of names.
	 * @return a list of instances having the names.
	 */
	public def getItemsByName0[T](kv:Map[String,List[T]], names:(i:Long)=>String, n:Long):List[T] {
		val items = new ArrayList[T]();
		for (i in 0..(n - 1)) {
		    val r = getItemsByName0[T](kv, names(i));
		    if(r==null) Console.OUT.println("~~~~" + here+ ":"+ kv +":"+names(i));
		    else items.addAll(r);
		}
		return items;
	}

	/**
	 * Get a list of items (instances) stored in GLOBAL specified by the list of names.
	 * @param json  section name(s) (String or List) defined in the JSON config file.
	 * @return a list of instances having the name(s).
	 */
	public def getItemsByName0[T](kv:Map[String,List[T]], json:JSON.Value):List[T] {
		if (json.isList()) {
			return getItemsByName0[T](kv, (i:Long) => json(i).toString(), json.size());
		}
		return getItemsByName0[T](kv, json.toString());
	}

	/**
	 * Get an item (instance) stored in GLOBAL by the name.
	 * Since in GLOBAL even a single item is stored as <code>List</code>, the size must be 1.
	 * This throws an exception if the size is &gt; 1.
	 * @param json  a section name (String or List) defined in the JSON config file.
	 * @return an instance having the name.
	 */
	public def getItemByName0[T](kv:Map[String,List[T]], json:JSON.Value):T {
		val items = getItemsByName0[T](kv, json);
		assert items.size() == 1 : "getItemByName0() got more than one object";
		return items(0);
	}


	//** Here are a list of utility methods to access to GLOBAL. */
    private def marketConverter1(range:LongRange):Market {
	return markets(range.min);
    }
    private def marketConverterM(ranges:List[LongRange]):List[Market] {
//	Console.OUT.println(""+here+"converterM:"+ranges + ":"+ markets);
	val result = new ArrayList[Market]();
	for(range in ranges) for(i in range) result.add(markets(i));
	return result;
    }


    
	public def getMarketsByName(json:JSON.Value) {
	    return marketConverterM(getItemsByName0[LongRange](marketName2Ranges,json));
	}

    public def getMarketByName(json:JSON.Value) = marketConverter1(getItemByName0[LongRange](marketName2Ranges,json));

    public def getMarketsByName(names:List[String]) = marketConverterM(getItemsByName0[LongRange](marketName2Ranges,(i:Long) => names(i), names.size()));

    public def getMarketsByName(name:String) = marketConverterM(getItemsByName0[LongRange](marketName2Ranges,name));

    public def getMarketByName(name:String) = marketConverter1(getItemByName0[LongRange](marketName2Ranges,name));

	public def getAgentsByName(json:JSON.Value) = getItemsByName[Agent](json);

	public def getAgentByName(json:JSON.Value) = getItemByName[Agent](json);

	public def getAgentsByName(names:List[String]) = getItemsByName[Agent]((i:Long) => names(i), names.size());

	public def getAgentsByName(name:String) = getItemsByName[Agent](name);

	public def getAgentByName(name:String) = getItemByName[Agent](name);

	public def getEventsByName(json:JSON.Value) = getItemsByName[Event](json);

	public def getEventByName(json:JSON.Value) = getItemByName[Event](json);

	public def getEventsByName(names:List[String]) = getItemsByName[Event]((i:Long) => names(i), names.size());

	public def getEventsByName(name:String) = getItemsByName[Event](name);

	public def getEventByName(name:String) = getItemByName[Event](name);
}
