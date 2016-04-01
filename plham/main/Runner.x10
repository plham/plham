package plham.main;
import x10.io.File;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.HashSet;
import x10.util.HashMap;
import x10.util.Set;
import x10.util.Random;
import cassia.util.random.RandomPermutation;
import plham.Agent;
import plham.HighFrequencyAgent;
import plham.Env;
import plham.Fundamentals;
import plham.IndexMarket;
import plham.Market;
import plham.Order;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.util.JSONUtils;

/**
 * A base class for execution models.
 * See {@link plham.main.Simulator} for simulation models.
 * This class is basically for system developers.
 */
public abstract class Runner[B]{B <: Simulator} {

	var sim:B;

	public var _PROFILE:Boolean = false;

    public static val useTeam:Boolean = true;
    
    public def this(sim:B) {
    	this.sim = sim;
    }

	public def env():Env = this.sim;

	public def handleOrders(localOrders:List[List[Order]], MAX_HIFREQ_ORDERS:Long):List[List[Order]] {
		val env = this.env();
		val beginTime = System.nanoTime();
		val allOrders = new ArrayList[List[Order]]();
		val markets = env.markets;

		val random = sim.getRandom();
        val agents = env.hifreqAgents; 
		val randomAgents = new RandomPermutation[Agent](random, agents);
		val randomOrders = new RandomPermutation[List[Order]](random, localOrders);

		randomOrders.shuffle();
		for (someOrders in randomOrders) {
			// This handles one order-list submitted by an agent per loop.
			// TODO: If needed, one-market one-order handling.
			for (order in someOrders) {
				val m = env.markets(order.marketId);
				m.triggerBeforeOrderHandlingEvents(order);
				m.handleOrder(order); // NOTE: DO it now.
				m.triggerAfterOrderHandlingEvents(order);
				m.tickUpdateMarketPrice();
			}

			var k:Long = 0;
			randomAgents.shuffle();
			for (agent in randomAgents) {
				if (k >= MAX_HIFREQ_ORDERS) {
					break;
				}
				val orders = agent.submitOrders(markets);
				if(!orders.isEmpty()) allOrders.add(orders);

				if (orders.size() > 0) {
					for (order in orders) {
						val m = env.markets(order.marketId);
						m.triggerBeforeOrderHandlingEvents(order);
						m.handleOrder(order);
						m.triggerAfterOrderHandlingEvents(order);
						m.tickUpdateMarketPrice();
					}
					k++;
				}
			}

		}

		val endTime = System.nanoTime();
		if (_PROFILE) {
			Console.OUT.println("#PROFILE ORDER-EXEC TOTAL " + ((endTime - beginTime) / 1e+9) + " sec");
			Console.OUT.println("#PROFILE MAX-HIFREQ-ORDERS " + MAX_HIFREQ_ORDERS + " x " + localOrders.size());
			Console.OUT.println("#PROFILE NUM-HIFREQ-ORDERS " + allOrders.size());
		}
		return allOrders;
	}
	
	public def updateAgents() {
		val env = this.env();
		val marketIds = new ArrayList[Long]();
		val updates = new ArrayList[List[Market.AgentUpdate]]();
		for (market in env.markets) {
			val t = market.getTime();
			val logs = market.agentUpdates(t);
			marketIds.add(market.id);
			updates.add(logs);
		}
		val n = env.markets.size();
		for (i in 0..(n - 1)) {
			val id = marketIds(i);
			val logs = updates(i);
			env.markets(id).executeAgentUpdates(env.agents, logs);
		}
	}

	def syncCheck(markets:List[Market]) {
		val env = this.env();
		val N_PLACES = Place.numPlaces(); 
		for (m in markets) {
			val id = m.id;
			val price = env.markets(id).getPrice();
			val size = env.markets(id).marketPrices.size();
			val time = env.markets(id).getTime();
		}
		Console.OUT.println("#SyncCheck: OK");
	}
	
	public abstract def updateMarkets(maxNormalOrders:Long, maxHifreqOrders:Long, 
			diffPass:Boolean): void; 
	
	public def iterateMarketUpdates(sessionName:String, iterationSteps:Long,
			withOrderPlacement:Boolean, withOrderExecution:Boolean, withPrint:Boolean, forDummyTimeseries:Boolean,
			maxNormalOrders:Long, maxHifreqOrders:Long,
			fundamentals:Fundamentals) {
		val env = this.env();
		val markets = env.markets;  
		for (market in markets) {
			market.setRunning(withOrderExecution);
		}
		for (market in markets) {
			market.cleanOrderBooks(market.getPrice()); // Better to use plham.util.Itayose?
		}
		for (market in markets) {
			market.check();
		}
		for (t in 1..iterationSteps) {
			for (market in markets) {
				market.triggerBeforeSimulationStepEvents(); // Assuming the markets in dependency order.
			}

			if (withOrderPlacement) {
				updateMarkets(maxNormalOrders, maxHifreqOrders, t > 0);
			}
			
			sim.updateFundamentals(fundamentals);
			if (forDummyTimeseries) {
				sim.updateMarketsUsingFundamentalPrice(markets, fundamentals);
			} else {
				sim.updateMarketsUsingMarketPrice(markets, fundamentals);
			}

			if (withPrint) {
				sim.print(sessionName);
			}

			for (market in markets) {
				market.triggerAfterSimulationStepEvents();
			}
			
			for (market in markets) {
				market.updateTime();
			}
		}
	}

	public def setupEnv(markets:List[Market],agents:List[Agent]) {
		val env = this.env();
		val normalAgents = new ArrayList[Agent]();
		val hifreqAgents = new ArrayList[Agent]();
		for (a in agents) {
			if (a instanceof HighFrequencyAgent) {
				hifreqAgents.add(a);
			} else {
				normalAgents.add(a);
			}
		}
		
		for (m in markets) { m.env = env; }
		env.markets = markets;
		env.agents = agents;
		env.normalAgents = normalAgents;
		env.hifreqAgents = hifreqAgents;
	}
	
	public def run(args:Rail[String]) {
		if (args.size < 1) {
			throw new Exception("Usage: ./a.out config.json [SEED]");
		}

		val seed:Long;
		if (args.size > 1) {
			seed = Long.parse(args(1));
		} else {
			seed = new Random().nextLong(Long.MAX_VALUE / 2); // MEMO: main()
		}

		Console.OUT.println("# X10_NPLACES  " + Env.getenvOrElse("X10_NPLACES", ""));
		Console.OUT.println("# X10_NTHREADS " + Env.getenvOrElse("X10_NTHREADS", ""));

		val TIME_THE_BEGINNING = System.nanoTime();

		val GLOBAL = new HashMap[String,Any]();
		sim.GLOBAL = GLOBAL;
		val CONFIG = JSON.parse(new File(args(0)));
		sim.CONFIG = CONFIG;
		JSON.extend(CONFIG);

		val RANDOM = new Random(seed);
		sim.RANDOM = RANDOM;
		Console.OUT.println("# Random.seed " + seed);

		//////// MULTIVARIATE GEOMETRIC BROWNIAN ////////

		val fundamentals = sim.createFundamentals(CONFIG("simulation")("fundamentalCorrelations", "{}"), CONFIG("simulation")("markets"));
		sim.updateFundamentals(fundamentals);
		GLOBAL("fundamentals") = fundamentals as Any;


		//////// MARKETS INSTANTIATION ////////

		val markets = sim.createAllMarkets(CONFIG("simulation")("markets"));
		GLOBAL("markets") = markets;

		Console.OUT.println("# #(markets) " + markets.size());


		//////// AGENTS INSTANTIATION ////////

		val agents = sim.createAllAgents(CONFIG("simulation")("agents"));
		GLOBAL("agents") = agents;
		

		//////// SERIAL/PARALLEL ENV SETUP ////////

		setupEnv(markets, agents);

//		Console.OUT.println("# #(agents) " + agents.size());
//		Console.OUT.println("# #(hifreqAgents) " + env().hifreqAgents.size());

		//////// MAIN SIMULATION PROCEDURE ////////

		sim.beginSimulation();

		val sessions = CONFIG("simulation")("sessions");
		for (i in 0..(sessions.size() - 1)) {
			val json = sessions(i);
			val sessionName = json("sessionName").toString();
			val iterationSteps = json("iterationSteps").toLong();
			val withOrderPlacement = json("withOrderPlacement").toBoolean();
			val withOrderExecution = json("withOrderExecution").toBoolean();
			val withPrint = json("withPrint", "true").toBoolean();
			var forDummyTimeseries:boolean = (!withOrderPlacement && !withOrderExecution);
			if (json.has("forDummyTimeseries")) {
				forDummyTimeseries = json("forDummyTimeseries").toBoolean();
			}
			val maxNormalOrders = json("maxNormalOrders", markets.size().toString()).toLong();
			val maxHifreqOrders = json("maxHifreqOrders", "0").toLong();

			if (true) {
				Console.OUT.println("# SESSION: " + sessionName);
				Console.OUT.println("# iterationSteps: " + iterationSteps);
				Console.OUT.println("# withOrderPlacement: " + withOrderPlacement);
				Console.OUT.println("# withOrderExecution: " + withOrderExecution);
				Console.OUT.println("# withPrint: " + withPrint);
				Console.OUT.println("# forDummyTimeseries: " + forDummyTimeseries);
				Console.OUT.println("# maxNormalOrders: " + maxNormalOrders);
				Console.OUT.println("# maxHifreqOrders: " + maxHifreqOrders);
			}

			GLOBAL("events") = null;
			if (json.has("events")) {
				val events = sim.createAllEvents(json("events"));
				GLOBAL("events") = events;
			}

			sim.beginSession(sessionName);

			iterateMarketUpdates(
					sessionName, iterationSteps,
					withOrderPlacement, withOrderExecution, withPrint, forDummyTimeseries,
					maxNormalOrders, maxHifreqOrders,
					fundamentals);
			
			sim.endSession(sessionName);
		}

		sim.endSimulation();

		val TIME_THE_END = System.nanoTime();
		Console.OUT.println("# TIME " + ((TIME_THE_END - TIME_THE_BEGINNING) / 1e+9));
	}
}
