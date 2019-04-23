package plham.main;

import x10.compiler.Inline;
import x10.compiler.TransientInitExpr;
import x10.io.File;
import x10.io.CustomSerialization;
import x10.io.Deserializer;
import x10.io.Serializer;
import x10.io.Unserializable;
import x10.util.concurrent.*;
import x10.util.*;
import x10.xrx.*;
import cassia.concurrent.Affinity;
import cassia.concurrent.Daemon;
import cassia.concurrent.DedicatedWorker;
import cassia.concurrent.Pool;
import cassia.dist.*;
import cassia.util.*;
import plham.Agent;
import plham.HighFrequencyAgent;
import plham.Env;
import plham.Fundamentals;
import plham.Market;
import plham.Order;
import plham.util.DistAllocManager;
import plham.util.JSON;
import plham.util.JSONUtils;
import plham.util.RandomSequenceBySplit;

/****
 * This class assumes a customized X10 at the following links.
 *    ver2.6.0 + customization: https://gittk.cs.kobe-u.ac.jp/x10kobeu/x10kobeu/tree/x10-2.6.0kobeu+stl
 *    ver2.5.4 + customization: https://gittk.cs.kobe-u.ac.jp/x10kobeu/x10kobeu/tree/x10-2.5.4kobeu+stl
 */

public final class ParallelRunnerDist[B] {B haszero, B isref, B <: Simulator} extends Runner[B] implements CustomSerialization {
	
	private static val NPLACES: Long = Place.numPlaces();
	
	private static val NTHREADS: Long = Runtime.NTHREADS as Long;
	
	private static val WITH_DAEMON_THREAD: Boolean = initializeWithDaemonThread();
	private static def initializeWithDaemonThread(): Boolean {
		if (System.getenv("WITH_DAEMON_THREAD") == null) {
			return false;
		}
		if (System.getenv("WITH_DAEMON_THREAD").equals("0")) {
			return false;
		}
		if (System.getenv("WITH_DAEMON_THREAD").equals("false")) {
			return false;
		}
		return true;
	}
	
	private static val WITH_WORKER_POOL: Boolean = initializeWithWorkerPool();
	private static def initializeWithWorkerPool(): Boolean {
		if (System.getenv("WITH_WORKER_POOL") == null) {
			return true;
		}
		if (System.getenv("WITH_WORKER_POOL").equals("0")) {
			return false;
		}
		if (System.getenv("WITH_WORKER_POOL").equals("false")) {
			return false;
		}
		return true;
	}
	
	private static val WITH_TIME_STAMP: Boolean = initializeWithTimeStamp();
	private static def initializeWithTimeStamp(): Boolean {
		if (System.getenv("WITH_TIME_STAMP") == null) {
			return false;
		}
		if (System.getenv("WITH_TIME_STAMP").equals("0")) {
			return false;
		}
		if (System.getenv("WITH_TIME_STAMP").equals("false")) {
			return false;
		}
		return true;
	}
	
	private static val NUM_COMPUTATION_THREADS: Long = initializeNumComputationThreads();
	private static def initializeNumComputationThreads(): Long {
		assert(1 < NTHREADS);
		val max: Long;
		if (WITH_DAEMON_THREAD) {
			assert(2 < NTHREADS);
			max = (NTHREADS - 2) as Long;
		} else {
			max = (NTHREADS - 1) as Long;
		}
		if (System.getenv("NUM_COMPUTATION_THREADS") == null) {
			return max;
		}
		val fromEnv = Long.parse(System.getenv("NUM_COMPUTATION_THREADS"));
		if (max < fromEnv) {
			return max;
		}
		if (fromEnv < 1) {
			return 1;
		}
		return fromEnv;
	}
	
	private static val SHORT_TERM_AGENTS_RATE: Double = initializeShortTermAgentsRate();
	private static def initializeShortTermAgentsRate(): Double {
		if (System.getenv("SHORT_TERM_AGENTS_RATE") == null) {
			return 0.5;
		}
		val fromEnv = Double.parse(System.getenv("SHORT_TERM_AGENTS_RATE"));
		if (1.0 < fromEnv) {
			return 1.0;
		}
		if (fromEnv < 0.0) {
			return 0.0;
		}
		return fromEnv;
	}
	
	private static def getPool(): Pool {
		if (WITH_WORKER_POOL) {
			return Pool.getInstance();
		}
		return null;
	}

	private static def holdWorkers(nworkers: Long): void {
		val pool = getPool();
		if (pool != null) {
			pool.hold(nworkers);
		}
	}

	private static def releaseWorkers(): void {
		val pool = getPool();
		if (pool != null) {
			pool.release();
		}
	}
	
	private static def time(closure: ()=>void): Double {
		val begin = System.nanoTime();
		closure();
		val end = System.nanoTime();
		return (end - begin) * 1e-9;
	}

	private final static def debug(o: Any): void {
		Console.ERR.println(o);
	}

	static class AgentGenerator[C] {C haszero, C isref, C <: Simulator} {
		
		val dist: Dist[C];
		
		@TransientInitExpr(getSimInternal())
		transient val sim: Simulator;
		private final def getSimInternal(): Simulator {
			return dist.sim;
		}

		@TransientInitExpr(getPlaceGroupInternal())
		transient val placeGroup: PlaceGroup;
		private final def getPlaceGroupInternal(): PlaceGroup {
			return dist.placeGroup;
		}

		@TransientInitExpr(getTeamInternal())
		transient val team: Team;
		private final def getTeamInternal(): Team {
			return dist.team;
		}

		@TransientInitExpr(getMasterInternal())
		transient val master: Place;
		private final def getMasterInternal(): Place {
			return dist.master;
		}

		@TransientInitExpr(getAllAgentsInternal())
		transient val allAgents: DistCol[Agent];
		private final def getAllAgentsInternal(): DistCol[Agent] {
			return dist.agents as DistCol[Agent];
		}

		@TransientInitExpr(getShortTermAgentsInternal())
		transient val shortTermAgents: DistCol[Agent];
		private final def getShortTermAgentsInternal(): DistCol[Agent] {
			return dist.shortTermAgents;
		}

		@TransientInitExpr(getLongTermAgentsInternal())
		transient val longTermAgents: DistCol[Agent];
		private final def getLongTermAgentsInternal(): DistCol[Agent] {
			return dist.longTermAgents;
		}

		def this(runner: ParallelRunnerDist[C]) {
			this.dist = runner.dist;
			this.sim = getSimInternal();
			this.placeGroup = getPlaceGroupInternal();
			this.team = getTeamInternal();
			this.master = getMasterInternal();
			this.allAgents = getAllAgentsInternal();
			this.shortTermAgents = getShortTermAgentsInternal();
			this.longTermAgents = getLongTermAgentsInternal();
		}

		final def env(): Env {
			return sim;
		}

		def getWorkerIndex(): Long {
			val align = placeGroup.size() - 1 - placeGroup.indexOf(master);
			return (placeGroup.indexOf(here) + align) % placeGroup.size();
		}

		def getAssignedRange(allRange: LongRange): LongRange {
			val hereIndex = getWorkerIndex();
			val numAgents = (allRange.max - allRange.min + 1);
			val numWorkers = placeGroup.size() - 1;
			val base = numAgents / numWorkers;
			val remain = numAgents - base * numWorkers;
			val from: Long = allRange.min + base * hereIndex + Math.min(hereIndex, remain);
			val count: Long = hereIndex < remain ? base + 1 : base;
			val range = (from .. (from + count - 1));
			return range;
		}
		
		def createAllAgents(list: JSON.Value): void {
			val randoms = new RandomSequenceBySplit(sim.getRandom());
			placeGroup.broadcastFlat(() => {
//				Console.OUT.println("---start@"+here);
				env().hifreqAgents = new ArrayList[Agent]();
				assert shortTermAgents != null : here + " createAllAgents(): shortTermAgents is null";
				assert longTermAgents != null : here + " createAllAgents(): longTermAgents is null";
				assert env().hifreqAgents != null : here + " createAllAgents() : hifreqAgents is null";
				assert list != null : here + " ParallelRunnerDist#createAllAgents(): list is null";
				assert sim != null : here + " ParallelRunnerDist#createAllAgents(): sim is null";
				assert sim.CONFIG != null : here + " ParallelRunnerDist#createAllAgents(): CONFIG is null";
				val dm = new DistAllocManager[Agent]() {
				    public def setTotalCount(size:Long) {
						//TODObyTK
						// Console.OUT.println("--- SIZE:"+size +"@"+here);
						env().numAgents = size;
						// Console.OUT.println("---- SIZE again@"+here + ":" + env().agents.size());
				    }
				    public def getRangedList(place:Place,config:JSON.Value,range:LongRange):RangedList[Agent] {
					    val className = config("class");
					    val classType = config("schedule");
					    if(place==master) {
							if (classType.equals("arbitrager")) {
								debug(here + " rangeForArbitrage = " + range);
								debug(here + " type " + env().agents);
								val chunk = new Chunk[Agent](range);
								allAgents.putChunk(chunk);
								return chunk;
							} else {
								return RangedListView.emptyView[Agent]();
							}
					    } else {
							if (classType.equals("arbitrager")) {
								return RangedListView.emptyView[Agent]();
							} else {
								val longType = classType.equals("longTerm");
								val myrange = getAssignedRange(range);
								val chunk = new Chunk[Agent](myrange);
								allAgents.putChunk(chunk);
								if(longType) longTermAgents.putChunk(chunk);
								else shortTermAgents.putChunk(chunk);
								debug("place:"+here+" alloc "+myrange+ " @" + (longType?"long":"short"));
								return chunk;
							} 
					    }
					}
				};
				sim.createAllAgents(list, dm);
				});
		}
		
		def createArbitrageAgents(randoms:Indexed[Random], range: LongRange, json: JSON.Value, name: String): void {
			val receiver = env().agents as List[Agent]; // TODO tk
			assert receiver != null : here + " ParallelRunnerDist#createArbitrageAgents(): receiver is null";
			sim.createAgents(name, randoms, range, json, receiver);
		}
	}


	static class SimulationParameter(sessionName:String, iterationSteps:Long, withOrderPlacement:Boolean, withOrderExecution:Boolean, withPrint:Boolean, forDummyTimeseries:Boolean, maxNormalOrders:Long, maxHifreqOrders:Long, fundamentals:Fundamentals) {}

	static class Step(id: Long, epoch: Long) {
		
		val sb: StringBuilder = new StringBuilder();
		val lock: Lock = new Lock();
		
		def log(message: String): void {
			val stamp = System.currentTimeMillis() - epoch;
			lock.lock();
			sb.add(this + " " + message + " " + stamp + "\n");
			lock.unlock();
		}
		
		def message(): void {
			Console.ERR.print(sb);
		}
		
		public def toString(): String {
			return "#" + here + " " + id;
		}
	}
	

	static class Dist[C](placeGroup: PlaceGroup, team: Team, master: Place) {C haszero, C isref, C <: Simulator} {

		transient var runner: Runner[C];
		val plh: PlaceLocalHandle[C];

		@TransientInitExpr(getSimInternal())
		transient val sim: C;
		private final def getSimInternal(): C {
			return plh();
		}

		val agents: DistCol[Agent];
		var markets: CacheableArray[Market];
		val shortTermAgents: DistCol[Agent];
		val longTermAgents: DistCol[Agent];
		val shortTermOrders: DistBag[List[Order]];
		val longTermOrders: DistBag[List[Order]];
		val contractedOrders: DistMap[Long, List[Market.AgentUpdate]];

		def isMaster() = (here==master);
		var isLogging:Boolean = false;


		transient var agentDistribution: Rail[Place];

		@TransientInitExpr(getAgentIdsInternal())
		transient val agentIds: Set[Long];
		private final def getAgentIdsInternal(): Set[Long] {
			return new HashSet[Long]();
		}

		def this(placeGroup: PlaceGroup, team: Team, master: Place, creator: ()=>C) {
			property(placeGroup, team, master);
			plh = PlaceLocalHandle.makeFlat[C](placeGroup, creator);
			sim = getSimInternal();
			val agents0 = new DistCol[Agent](placeGroup, team);
			sim.agents = this.agents = agents0;
			longTermAgents = new DistCol[Agent](placeGroup, team);
			shortTermAgents = new DistCol[Agent](placeGroup, team);
			longTermOrders = new DistBag[List[Order]](placeGroup, team);
			shortTermOrders = new DistBag[List[Order]](placeGroup, team);
			val cOrders = new DistMap[Long, List[Market.AgentUpdate]](placeGroup, team);
			contractedOrders = cOrders;
			val agentProxy = (id:Long)=> {return new AgentUpdateProxy(id,cOrders);};
			agents0.setProxy(agentProxy);
			agentIds = getAgentIdsInternal();
		}

		final def env(): Env {
			return sim;
		}

		@Inline
		def wrap(step:Step, tag:String, cls:()=>void) {
			if(isLogging) step.log("begin " + tag + ":" +step);
			Console.OUT.println(step + " " + tag + " " + time(() => { cls(); }));
			if(isLogging) step.log("end " + tag + ":" +step);
		}
		def printLog(step: Step) {
			if(isLogging) step.message();
		}

		def broadcastMarketInformation(step:Step, simParam: SimulationParameter): void {
			wrap(step, "broadcastMarketInformation", () => {
				markets.broadcast(MarketInfo.pack, MarketInfo.unpack);
			});
		}

		def gatherShortTermOrders(step:Step, simParam: SimulationParameter): void {
			wrap(step, "gatherShortTermOrders", ()=> {
				shortTermOrders.gather(master);
			});
		}

		def gatherLongTermOrders(step:Step, simParam: SimulationParameter): void {
			wrap(step, "gatherLongTermOrders", ()=> {
				if (0 < step.id) {
					longTermOrders.gather(master);
				}
			});
		}

		def submitShortTermOrders(step:Step, simParam: SimulationParameter): void {
			wrap(step, "submitShortTermOrders", ()=> {
				submitOrders(shortTermAgents, shortTermOrders);
			});
		}

		def asyncSubmitShortTermOrders(step:Step, 
									   simParam: SimulationParameter): Condition {
			return asyncSubmitOrders(shortTermAgents, shortTermOrders);
		}

		def submitLongTermOrders(step:Step, simParam: SimulationParameter): void {
			wrap(step, "submitLongTermOrders", ()=> {
				if (step.id < simParam.iterationSteps - 1) 
					submitOrders(longTermAgents, longTermOrders);
			});
		}

		def asyncSubmitLongTermOrders(step: Step, 
									  simParam: SimulationParameter): Condition {
			if (step.id < simParam.iterationSteps - 1) {
				return asyncSubmitOrders(longTermAgents, longTermOrders);
			}
			val condition = new Condition();
			condition.release();
			return condition;
		}

		@Inline final def submitOrders(agents: DistCol[Agent], bag: DistBag[List[Order]]): void {
			assert here != master;
			val pool = getPool();
			agents.each(pool, bag, NUM_COMPUTATION_THREADS, (a: Agent, receiver: Receiver[List[Order]]) => {
				val orders = a.submitOrders(markets);
				if (!orders.isEmpty()) {
					receiver.receive(orders);
				}
			});
		}

		@Inline final def asyncSubmitOrders(agents: DistCol[Agent], bag: DistBag[List[Order]]): Condition {
			//			debug("start calc@"+here+":"+agents.ranges() + ":"+agents);
			assert here != master;
			val pool = getPool();
			return agents.asyncEach(pool, bag, NUM_COMPUTATION_THREADS, (a: Agent, receiver: Receiver[List[Order]]) => {
				val orders = a.submitOrders(markets);
				if (!orders.isEmpty()) {
					receiver.receive(orders);
				}
			});
		}

		def handleOrders(step:Step, simParam: SimulationParameter): void {
			wrap(step, "handleOrders", () => {
				assert here == master;

				val count = shortTermOrders.size() + longTermOrders.size();
				val allOrders = new ArrayList[List[Order]](count);
				allOrders.addAll(shortTermOrders);
				shortTermOrders.clear();
				allOrders.addAll(longTermOrders);
				longTermOrders.clear();
				runner.handleOrders(allOrders, simParam.maxHifreqOrders);
				allOrders.clear();
			});
		}

		def broadcastAgentUpdates(step:Step, simParam: SimulationParameter): void {
			wrap(step, "broadcastAgentUpdates", ()=> {
				updateAgentDistribution(); // acquire the distribution of agents
				contractedOrders.relocate(agentDistribution);
			});
		}
		def set2str[T](set:Container[T]):String {
			val sb = new StringBuilder();
			sb.add("[");
			for(e in set){
				sb.add(""+e + ", ");
			}
			sb.add("]");
			return sb.toString();
        }
		def map2str(map:Map[Long, List[Market.AgentUpdate]]):String {
			val sb = new StringBuilder();
			sb.add("[");
			for(k in map.keySet()){
				sb.add("("+k+ ":"+map(k)+")");
			}
			sb.add("]");
			return sb.toString();
        }

		def updateAgents(step:Step, simParam: SimulationParameter): void {
			wrap(step, "updateAgents", () => {
			var count: Long = 0;
			for (id in idRange()) {
				count += acceptAll(agents(id), contractedOrders.get(id));
				contractedOrders.remove(id);
			}
			});
		}

		def idRange(): Container[Long] {
			return agentIds;
		}
		
		//TODO should be moved to DistCol facility.
		def updateAgentDistribution(): void {
			agentIds.clear();
			val pairsBuilder = new RailBuilder[Pair[Long, Place]]();
			for (agent in env().hifreqAgents) {
				pairsBuilder.add(Pair[Long, Place](agent.id, here));
				agentIds.add(agent.id);
			}
			for (agent in shortTermAgents) {
				pairsBuilder.add(Pair[Long, Place](agent.id, here));
				agentIds.add(agent.id);
			}
			for (agent in longTermAgents) {
				pairsBuilder.add(Pair[Long, Place](agent.id, here));
				agentIds.add(agent.id);
			}
			val pairs = pairsBuilder.result();
			val dummyPairsCounts = new Rail[Int](team.size(), pairs.size as Int);
			val pairsCounts = new Rail[Int](team.size());
			team.alltoall(dummyPairsCounts, 0, pairsCounts, 0, 1);
			if (here == master) {
				var allPairsCount: Long = 0;
				for (count in pairsCounts) {
					allPairsCount += count;
				}
				val allPairs = new Rail[Pair[Long, Place]](allPairsCount);
				team.gatherv(master, pairs, 0, allPairs, 0, pairsCounts);
				if (agentDistribution == null) {
					agentDistribution = new Rail[Place](env().numAgents);
				}
				for (pair in allPairs) {
					agentDistribution(pair.first) = pair.second;
				}
			} else {
				team.gatherv(master, pairs, 0, null, 0, pairsCounts);
			}
		}

		def acceptAll(agent: Agent, updates: Container[Market.AgentUpdate]): Long {
			if (updates == null) {
				return 0;
			}
			for (update in updates) {
				agent.executeUpdate(update);
			}
			return updates.size();
		}
	}
    static class AgentUpdateProxy extends Agent.Proxy {
		val cOrders: DistMap[Long, List[Market.AgentUpdate]];
		def this(id:Long, cOrders: DistMap[Long, List[Market.AgentUpdate]]) {
			super(id);
			this.cOrders = cOrders;
		}
		public def executeUpdate(update:Market.AgentUpdate) {
			var list:List[Market.AgentUpdate] = cOrders(update.agentId);
			if (list == null) {
				list = new ArrayList[Market.AgentUpdate]();
				cOrders(update.agentId) = list;
			}
			list.add(update);
		}
	}


	static class LocalRunner[C](team: Team, master: Place) {C haszero, C isref, C <: Simulator} implements Unserializable {

		val dist: Dist[C];
		val simParam: SimulationParameter;
		val isMaster:Boolean;
		val sim:Simulator;

		def this(runner: ParallelRunnerDist[C], simParam: SimulationParameter) {
			property(runner.team, runner.master);
			this.dist = runner.dist;
			this.sim = runner.sim;
			this.simParam = simParam;
			this.isMaster = (here==runner.master);
		}

		def updateMarkets(master:Boolean, step:Step, simParm:SimulationParameter): void {
			var conditionShort:Condition = null;
			var conditionLong:Condition = null;

			dist.broadcastMarketInformation(step, simParam);
			if(!master) conditionShort = dist.asyncSubmitShortTermOrders(step, simParam);
			dist.gatherLongTermOrders(step, simParam);
			// Console.OUT.println("------------IterateLoop " + id + " lsend@"+here);
			if(!master) {
				conditionShort.await();
			// Console.OUT.println("------------IterateLoop " + id + " s await@"+here);
				conditionLong = dist.asyncSubmitLongTermOrders(step, simParam);
			}
			// Console.OUT.println("------------IterateLoop " + id + " lstart@"+here);
			dist.gatherShortTermOrders(step, simParam);
			if(master) dist.handleOrders(step, simParam);
			// Console.OUT.println("------------IterateLoop " + id + " ssend@"+here);
			dist.broadcastAgentUpdates(step, simParam);
			// Console.OUT.println("------------IterateLoop " + id + " uprcv@"+here);
			if(!master) conditionLong.await();
			// Console.OUT.println("------------IterateLoop " + id + " lwait@"+here);
			dist.updateAgents(step, simParam);
			// Console.OUT.println("------------IterateLoop " + id + " upagent@"+here);
			dist.printLog(step);
		}
		def marketSetup(markets: CacheableArray[Market]): void {
			for (market in markets) {
				market.setRunning(simParam.withOrderExecution);
			}
			for (market in markets) {
				// market.cleanOrderBooks(market.getPrice());
				market.itayoseOrderBooks();
			}
			for (market in markets) {
				market.check();
			}
		}
		def workerRun(): void {
			if (WITH_DAEMON_THREAD) {
				holdWorkers(NTHREADS - 2);
				val daemon = new Daemon();
				daemon.start();
				iterate();
				daemon.stop();
			} else {
				holdWorkers(NTHREADS - 1);
				iterate();
			}
			releaseWorkers();
		}
		def masterRun(): void {
			marketSetup(dist.markets);
			iterate();
		}
		def run(): void {
			if(isMaster) masterRun();
			else workerRun();
		}
		def iterSetup() {
			sim.updateFundamentals(simParam.fundamentals);
			for (market in sim.markets) {
				market.triggerBeforeSimulationStepEvents(); // Assuming the markets in dependency order.
			}
		}
		def iterate(): void {
			val epoch = System.currentTimeMillis();
			for (id in 0..(simParam.iterationSteps - 1)) {
				assert simParam.withOrderPlacement;
				//	Console.OUT.println("------------IterateLoop " + id + " @"+here);
				val step = new Step(id, epoch);
				val begin = System.nanoTime();
				if(isMaster) iterSetup();
				if (simParam.withOrderPlacement) {
					updateMarkets(isMaster, step, simParam);
				}
				if(isMaster) {
					if (simParam.forDummyTimeseries) {
						sim.updateMarketsUsingFundamentalPrice(sim.markets, simParam.fundamentals);
					} else {
						sim.updateMarketsUsingMarketPrice(sim.markets, simParam.fundamentals);
					}
					if (simParam.withPrint) {
						sim.print(simParam.sessionName);
					}
					for (market in sim.markets) {
						market.triggerAfterSimulationStepEvents();
					}
					for (market in sim.markets) {
						market.updateTime();
						market.updateOrderBooks();
					}
					val end = System.nanoTime();
					Console.OUT.println(step + " " + "CYCCLE " + ((end - begin) * 1e-9));
				}
			}
			if (isMaster && simParam.withPrint) {
				sim.endprint(simParam.sessionName, simParam.iterationSteps);
			}
		}
	}


	val plh: PlaceLocalHandle[Dist[B]];

	@TransientInitExpr(getDistInternal())
	transient val dist: Dist[B];
	private final def getDistInternal(): Dist[B] {
		return plh();
	}

	@TransientInitExpr(getPlaceGroupInternal())
	transient val placeGroup: PlaceGroup;
	private final def getPlaceGroupInternal(): PlaceGroup {
		return plh().placeGroup;
	}

	@TransientInitExpr(getTeamInternal())
	transient val team: Team;
	private final def getTeamInternal(): Team {
		return plh().team;
	}

	@TransientInitExpr(getMasterInternal())
	transient val master: Place;
	private final def getMasterInternal(): Place {
		return plh().master;
	}

	public def this(creator: ()=>B) {
		this(creator, Place.places(), Team.WORLD, Place(0));
	}

	def this(creator: ()=>B, placeGroup: PlaceGroup, team: Team, master: Place) {
		this(placeGroup, new Dist[B](placeGroup, team, master, creator));
	}

	def this(placeGroup: PlaceGroup, dist: Dist[B]) {
		this(PlaceLocalHandle.makeFlat(placeGroup, (): Dist[B] => dist));
	}

	def this(plh: PlaceLocalHandle[Dist[B]]) {
		super(plh().sim);
		this.plh = plh;
		this.dist = getDistInternal();
		this.placeGroup = getPlaceGroupInternal();
		this.team = getTeamInternal();
		this.master = getMasterInternal();
	}

	// override
	public def iterateMarketUpdates(sessionName:String, iterationSteps:Long, withOrderPlacement:Boolean, withOrderExecution:Boolean, withPrint:Boolean, forDummyTimeseries:Boolean, maxNormalOrders:Long, maxHifreqOrders:Long, fundamentals:Fundamentals): void {
		val simParam = new SimulationParameter(sessionName, iterationSteps, withOrderPlacement, withOrderExecution, withPrint, forDummyTimeseries, maxNormalOrders, maxHifreqOrders, fundamentals);
		placeGroup.broadcastFlat(() => {
			dist.runner = this;
			val localRunner = generateLocalRunner(simParam);
			Affinity.bind(0);
			team.nativeBarrier();
			localRunner.run();
		});
	}

	// override
	public def updateMarkets(Long, Long, Boolean): void {}

	// override
	public def setupEnv(markets: List[Market], agents: List[Agent]): void {
		// setupMarkets(markets);
		// setupAgents(agents);
	}

	/*	def setupMarkets(markets: List[Market]): void {
		val before = System.nanoTime();
		dist.markets = new CacheableArray[Market](placeGroup, team, markets);
		placeGroup.broadcastFlat(() => {
			env().markets = dist.markets.toList();
		});
		for (m in markets) {
			m.env = env();
		}
		val time = (System.nanoTime() - before) / 1.0e9;
		Console.OUT.println("#Dist InitialMarket total elapsed time:" + time);
		}*/

	def createAllMarkets(list: JSON.Value): List[Market] {
		val markets = sim.createAllMarkets(list);
		Console.OUT.println("#baseMarkets size:"+ markets.size() + ","+markets);	
		val tmp = new CacheableArray[Market](placeGroup, team, markets);
		val n2ranges = sim.marketName2Ranges;
		for(kv in n2ranges.entries()) Console.OUT.println("Group " + kv.getKey() +"@"+kv.getValue());
		placeGroup.broadcastFlat(() => {
			dist.markets = tmp;
			env().markets = dist.markets; // whose env??
			if (here != master) {
				/*				Console.OUT.println("---"+here+"-->Market");
				for (market in dist.markets) {
					if (dist.sim.GLOBAL(market.name) == null) {
						dist.sim.GLOBAL(market.name) = new ArrayList[Market]();
					}
					(dist.sim.GLOBAL(market.name) as List[Market]).add(market);
				Console.OUT.println("---"+here+"--Market:"+market.name);
				}
				Console.OUT.println("---"+here+"<--Market");*/
				dist.sim.marketName2Ranges = n2ranges;
				Console.OUT.println("#baseMarkets size(rcved@"+here+"):"+ env().markets.size() + ","+env().markets);	
			}
			for (market in env().markets) {
				market.env = env();
			}
		});
		Console.OUT.println("#baseMarkets size(again):"+ markets.size() + ","+markets);	
		return markets;
	}

	def createAllAgents(list: JSON.Value): List[Agent] {
		new AgentGenerator[B](this).createAllAgents(list);
		return env().agents;
	}

	def generateLocalRunner(simParam: SimulationParameter): LocalRunner[B] {
		if (WITH_TIME_STAMP) { 
			dist.isLogging = true;
		}
		return new LocalRunner[B](this, simParam);
	}

	def syncCheck(markets: List[Market]): void {
		val np = this.placeGroup.size();
		val distMarkets = this.dist.markets;
		val masterMarkets = this.dist.markets.toList();
		for (m in distMarkets) {
			// ensure that m.id == markets.indexOf(m)
			val id = m.id;
			val price = masterMarkets(id).getPrice();
			val size = masterMarkets(id).marketPrices.size();
			val time = masterMarkets(id).getTime();
			finish for (p in 1..(np - 1)) at (this.placeGroup(p)) async {
				val proxyMarkets = distMarkets.toList();
				val myprice = proxyMarkets(id).getPrice();
				val mysize = proxyMarkets(id).marketPrices.size();
				val mytime = proxyMarkets(id).getTime();
				assert time == mytime : ["time sync failure", time, mytime];
				assert size == mysize : ["size sync failute", size, mysize];
				assert price == myprice : ["price sync failure", price, myprice];
			}
		}
		Console.OUT.println("#SyncCheck: OK");
	}

	// override
	public def run(args:Rail[String]): void {
		if (args.size < 1) {
			throw new Exception("Usage: ./a.out config.json [SEED]");
		}

		val seed:Long;
		if (args.size > 1) {
			seed = Long.parse(args(1));
		} else {
			seed = new Random().nextLong(Long.MAX_VALUE / 2); // MEMO: main()
		}

		Console.OUT.println("#NPLACES=" + NPLACES);
		Console.OUT.println("#NTHREADS=" + NTHREADS);
		Console.OUT.println("#WITH_DAEMON_THREAD=" + WITH_DAEMON_THREAD);
		Console.OUT.println("#WITH_WORKER_POOL=" + WITH_WORKER_POOL);
		Console.OUT.println("#NUM_COMPUTATION_THREADS=" + NUM_COMPUTATION_THREADS);
		Console.OUT.println("#SHORT_TERM_AGENTS_RATE=" + SHORT_TERM_AGENTS_RATE);
		Console.OUT.println("#BS_WORKLOAD=" + Env.getenvOrElse("BS_WORKLOAD", "false"));
		Console.OUT.println("#BS_NSAMPLES=" + Env.getenvOrElse("BS_NSAMPLES", "100"));
		Console.OUT.println("#BS_NSTEPS=" + Env.getenvOrElse("BS_NSTEPS", "100"));
		Console.OUT.println("#ORDER_RATE=" + Env.getenvOrElse("ORDER_RATE", "0.1"));
		Console.OUT.println("#HIFREQ_SUBMIT_RATE=" + Runner.HIFREQ_SUBMIT_RATE);

		val TIME_THE_BEGINNING = System.nanoTime();

		val GLOBAL = new HashMap[String,Any]();
		sim.GLOBAL = GLOBAL;
		val CONFIG = JSON.parse(new File(args(0)));
		sim.CONFIG = CONFIG;
		JSON.extendDeeply(CONFIG, CONFIG);

		placeGroup.broadcastFlat(() => {
			if (here == master) {
				val s = new Serializer();
				s.writeAny(sim.GLOBAL);
				s.writeAny(sim.CONFIG);
				val buffer = s.toRail();
				val count = new Rail[Long](1, buffer.size);
				team.bcast(master, count, 0, count, 0, 1);
				team.bcast(master, buffer, 0, buffer, 0, count(0));
			} else {
				val count = new Rail[Long](1);
				team.bcast(master, count, 0, count, 0, 1);
				val buffer = new Rail[Byte](count(0));
				team.bcast(master, buffer, 0, buffer, 0, count(0));
				val ds = new Deserializer(buffer);
				sim.GLOBAL = ds.readAny() as Map[String, Any];
				sim.CONFIG = ds.readAny() as JSON.Value;
			}
			// val RANDOM = new Random(seed);
			val RANDOM = new Random(seed + here.id);
			sim.RANDOM = RANDOM;
		});

		Console.OUT.println("#Random.seed " + seed);

		//////// MARKETS INSTANTIATION ////////

		// val markets = sim.createAllMarkets(CONFIG("simulation")("markets"));
		val markets = createAllMarkets(CONFIG("simulation")("markets"));
		val mrange = new ArrayList[LongRange](); mrange.add(0..(markets.size()-1));
		//		GLOBAL("markets") = markets;
		sim.marketName2Ranges("markets") = mrange;

		//////// AGENTS INSTANTIATION ////////

		// val agents = sim.createAllAgents(CONFIG("simulation")("agents"));
		val agents = createAllAgents(CONFIG("simulation")("agents")); // this "agents" does not contains all Agents
		GLOBAL("agents") = agents;

		//////// MULTIVARIATE GEOMETRIC BROWNIAN ////////

		val fundamentals = sim.createFundamentals(markets, CONFIG("simulation")("fundamentalCorrelations", "{}"));
		sim.updateFundamentals(fundamentals);
		GLOBAL("fundamentals") = fundamentals;

		//////// SERIAL/PARALLEL ENV SETUP ////////

		// setupEnv(markets, agents);

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
			val forDummyTimeseries:boolean;
			if (json.has("forDummyTimeseries")) {
				forDummyTimeseries = json("forDummyTimeseries").toBoolean();
			} else {
				forDummyTimeseries = (!withOrderPlacement && !withOrderExecution);
			}
			val maxNormalOrders = json("maxNormalOrders", markets.size().toString()).toLong();
			val maxHifreqOrders = json("maxHifreqOrders", "0").toLong();

			Console.OUT.println("#SESSION: " + sessionName);
			Console.OUT.println("#iterationSteps: " + iterationSteps);
			Console.OUT.println("#withOrderPlacement: " + withOrderPlacement);
			Console.OUT.println("#withOrderExecution: " + withOrderExecution);
			Console.OUT.println("#withPrint: " + withPrint);
			Console.OUT.println("#forDummyTimeseries: " + forDummyTimeseries);
			Console.OUT.println("#maxNormalOrders: " + maxNormalOrders);
			Console.OUT.println("#maxHifreqOrders: " + maxHifreqOrders);

			GLOBAL("events") = null;
			if (json.has("events")) {
				val events = sim.createAllEvents(json("events"));
				GLOBAL("events") = events;
			}

			sim.beginSession(sessionName);

			iterateMarketUpdates(sessionName, iterationSteps, withOrderPlacement, withOrderExecution, withPrint, forDummyTimeseries, maxNormalOrders, maxHifreqOrders, fundamentals);

			sim.endSession(sessionName);
		}

		sim.endSimulation();

		val TIME_THE_END = System.nanoTime();
		Console.OUT.println("#TIME " + ((TIME_THE_END - TIME_THE_BEGINNING) / 1e+9));
	}

	public def serialize(s: Serializer): void {
		s.writeAny(plh);
	}

	public def this(ds: Deserializer) {
		this(ds.readAny() as PlaceLocalHandle[Dist[B]]);
	}
}


struct MarketInfo(_isRunning: Boolean, marketPrice: Double, fundamentalPrice: Double, time: Long) {

	static val pack = (m: Market): MarketInfo => {
		return MarketInfo(m._isRunning, m.marketPrices.getLast(), m.fundamentalPrices.getLast(), m.getTime());
	};

	static val unpack = (m: Market, mi: MarketInfo): void => {
		m._isRunning = mi._isRunning;
		m.marketPrices(mi.time)=mi.marketPrice;
		m.fundamentalPrices(mi.time)=mi.fundamentalPrice;
		m.setTime(mi.time);
	};
}

// Local Variables:
// indent-tabs-mode: t
// tab-width: 4
// End:
