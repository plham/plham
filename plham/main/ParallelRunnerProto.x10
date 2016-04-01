package plham.main;
import x10.util.ArrayList;
import x10.util.List;
import cassia.util.random.RandomPermutation;
import cassia.util.parallel.ConcatenatedList;
import cassia.util.parallel.ConcatenatedListReducer;
import cassia.util.parallel.BroadcastTools;
import plham.Agent;
import plham.HighFrequencyAgent;
import plham.Env;
import plham.Fundamentals;
import plham.IndexMarket;
import plham.Market;
import plham.Order;

/**
 * A Runner class for parallel execution.
 * This is currently a prototype implementation, under development.
 */
public class ParallelRunnerProto[B]{B haszero, B isref, B <: Simulator} extends Runner[B] {
	
	public var plhE:PlaceLocalHandle[B];
	public var creator:()=>B;
	
	public def this(creator:()=>B) {
		super(null);
		this.creator = creator;
		this.plhE = PlaceLocalHandle.makeFlat[B](Place.places(), creator);
		super.sim = this.plhE();
	}

	public def updateMarkets(var maxNormalOrders:Long, 
			var maxHifreqOrders:Long, var diffPass:Boolean):void {
				
		val orders = collectOrders(diffPass);
		handleOrders(orders, maxHifreqOrders);
		updateAgents();
	}
			
	public def collectOrders(diffPass:Boolean):List[List[Order]] {
		val N_PLACES = Place.numPlaces(); //Long.parse(System.getenv("X10_NPLACES"));
		val N_THREADS = Long.parse(Env.getenvOrElse("X10_NTHREADS", "1"));
		
		val markets = plhE().markets;
		plhE().orders = new ArrayList[List[Order]]();
		val beginTime = System.nanoTime();
		val marketDiff:Env.MarketsFlat = plhE().prepareMarketsF();
		val listOfOrders = BroadcastTools.broadcastReduce[List[List[Order]]] (
				BroadcastTools.workers, ConcatenatedListReducer[List[Order]](), () =>{ 
					if(here.id==0l) {
						if (_PROFILE) Console.OUT.println("#HOST return "+ here);
						return 	new ArrayList[List[Order]]();	
					}
					val _beginTime1= System.nanoTime();
					plhE().receiveMarketsF(marketDiff, diffPass);
					val time = plhE().markets(0).getTime();
					val _markets = plhE().markets;
					if (_PROFILE) Console.OUT.println("#HOST: " + here);
					val _agents = plhE().localAgents;
					val N = _agents.size();
					val _allOrders = new ArrayList[List[Order]]();
					finish for (t in 0..(N_THREADS - 1)) async { 
						val tempOrders = new ArrayList[List[Order]]();
						val jobNum = N / N_THREADS;
						val rem = N%N_THREADS;
						val from = jobNum*t + Math.min(t, rem);
						val to = jobNum*(t+1) + Math.min(t+1, rem);
						for (var i:Long = from; i < to; i++) {
							val agent = _agents(i);
							val orders = agent.submitOrders(_markets);
							if(!orders.isEmpty()) tempOrders.add(orders);
						}
						atomic _allOrders.addAll(tempOrders);
					}
					
					val _endTime1= System.nanoTime();
					if (_PROFILE) {
						Console.OUT.println("#PROFILE ORDER-MAKE-WORKER@" +here + ":" + time +  ", agents: + " + _agents.size() + ", orders: " + _allOrders.size() + ": " +((_endTime1 - _beginTime1) / 1e+9) + " sec");
					}
					plhE().orders = _allOrders;
					return _allOrders as List[List[Order]];
				});
		plhE().orders = (listOfOrders as ConcatenatedList[List[Order]]).toArrayList();
		
		val endTime = System.nanoTime();
		if (_PROFILE) {
			var numOrders:Long = 0;
			for (orders in plhE().orders) {
				numOrders += orders.size();
			}
			//			val seriByte = profile.bytes;
			//			val commTime = profile.communicationNanos;
			//			val seriTime = profile.serializationNanos;
			Console.OUT.println("#PROFILE NUM-PLACES " + N_PLACES);
			Console.OUT.println("#PROFILE NUM-THREADS " + N_THREADS);
			Console.OUT.println("#PROFILE NUM-SPOT-MARKETS " + markets.size());
//			Console.OUT.println("#PROFILE NUM-LOCAL-AGENTS " + agents.size());
			Console.OUT.println("#PROFILE NUM-ALL-ORDERS " + plhE().orders.size());
			Console.OUT.println("#PROFILE NUM-LOCAL-ORDERS " + numOrders);
			Console.OUT.println("#PROFILE ORDER-MAKE TOTAL " + ((endTime - beginTime) / 1e+9) + " sec");
			Console.OUT.println("#PROFILE BS_WORKLOAD " + Env.getenvOrElse("BS_WORKLOAD", "false") + ":" + 
					Env.getenvOrElse("BS_NSAMPLES", "0") + ":" + Env.getenvOrElse("BS_NSTEPS", "0"));
			//			Console.OUT.println("#PROFILE MPI-BYTES  " + (seriByte / N_PLACES) + " byte/place");
			//			Console.OUT.println("#PROFILE MPI-COMM   " + (commTime / 1e+9 / N_PLACES) + " comm-sec/place");
			//			Console.OUT.println("#PROFILE MPI-SERIAL " + (seriTime / 1e+9 / N_PLACES) + " seri-sec/place");
		}
		return plhE().orders;
	}		
	
	public def distributeInitialMarkets(markets:List[Market]) {
		val before = System.nanoTime();
		if(useTeam) {
			BroadcastTools.workers.broadcastFlat(()=>{
				assert(here.id!=0L);
				plhE().markets = markets;
			});
		} else { 
			finish {
				for (p in 1..(Place.numPlaces()-1)) {
					//async  at (Place(p)) 
					at (Place(p)) {
						plhE().markets = markets;
					}
				}
			}
			plhE().markets = markets;
		}
		Console.OUT.println("#Dist InitialMarket  total elapsed time:" + ((System.nanoTime()-before) / 1e+9));						
	}

	public def distributeInitialAgents(agents:List[Agent]) {
		val n = agents.size();
		if(useTeam) {
			BroadcastTools.workers.broadcastFlat(()=>{
				assert(here.id!=0L);
				val a = new ArrayList[Agent]();
				a.addAll(new Rail[Agent](n, (i:Long) => null));
				plhE().agents = a;
			});
		} else { 
			finish {
				for (p in 1..(Place.numPlaces()-1)) {
					//async  at (Place(p)) 
					at (Place(p)) {
						val a = new ArrayList[Agent]();
						a.addAll(new Rail[Agent](n, (i:Long) => null));
						plhE().agents = a;
					}
				}
			}
		}
		val a = new ArrayList[Agent]();
		a.addAll(new Rail[Agent](n, (i:Long) => null));
		plhE().agents = a;
	}

	public def distributeLocalAgents(agents:List[Agent]) {
		// TODO TK: Is it better to create localAgents at worker initially?
		// TODO TK: multi-layer distribution for large scale machines. or Use Team Propagation.
		Console.OUT.println("#distributeLocalAgents: nWorker = " + (Place.numPlaces()-1)); 
		val nWorker = Place.numPlaces()-1; // TK Master does not treat local agents 
		val nAgents = agents.size() / nWorker;
		val rem = agents.size()%nWorker;
		// Assume that master does not accept order-make
		val before = System.nanoTime();
		finish {
			for (p in 0..(nWorker - 1)) {
				val from = nAgents*p + Math.min(p, rem);
				val to = nAgents*(p+1) + Math.min(p+1, rem);
				val toMove = agents.subList(from, to);
				at(Place(p+1)) async { 
					plhE().localAgents = toMove;
					//
					for (a in toMove) {
						plhE().agents(a.id) = a;
					}
					Console.OUT.println("#Dist " + Place(p+1) + " Copied local agents");
				}
			}
			plhE().localAgents = new ArrayList[Agent]();
		}
		Console.OUT.println("#Dist LocalAgent after   total elapsed time:" + ((System.nanoTime()- before) / 1e+9));						                  
	}

	public def distributeHifreqAgents(agents:List[Agent]) {
		for (a in agents) {
			plhE().agents(a.id) = a;
		}
		Console.OUT.println("#Dist " + here + " Copied HFT agents");
	}
	
	public def updateAgents() {
		val marketIds = new ArrayList[Long]();
		val updates = new ArrayList[List[Market.AgentUpdate]]();
		for (market in plhE().markets) {
			val t = market.getTime();
			val logs = market.agentUpdates(t);
			marketIds.add(market.id);
			updates.add(logs);
		}
		finish {
			for (p in 1..(Place.numPlaces() - 1)) {
				val n = plhE().markets.size();
				// Single-thread update
				async at (Place(p)) {
					for (i in 0..(n - 1)) {
						val id = marketIds(i);
						val logs = updates(i);
						plhE().markets(id).executeAgentUpdates(plhE().agents, logs);
					}
				}
			}
		}
	}
	
	
	public def setupEnv(markets:List[Market],agents:List[Agent]) { // override
//		plhE = PlaceLocalHandle.makeFlat[B](Place.places(), ()=>{ return (here.id == 0)? sim : creator(); });
		for (m in markets) { m.env = plhE(); }
		val normalAgents = new ArrayList[Agent]();
		val hifreqAgents = new ArrayList[Agent]();
		for (a in agents) {
			if (a instanceof HighFrequencyAgent) {
				hifreqAgents.add(a);
			} else {
				normalAgents.add(a);
			}
		}
		plhE().markets = markets;
		plhE().agents = agents;
		plhE().normalAgents = normalAgents;
		plhE().hifreqAgents = hifreqAgents;
		plhE().initMarketsF(markets.size());
		distributeInitialAgents(agents);
		distributeLocalAgents(normalAgents);
		distributeHifreqAgents(hifreqAgents);
		distributeInitialMarkets(markets);
	}
	
	def syncCheck(markets:List[Market]) {
		val N_PLACES = Place.numPlaces(); 
		for (m in markets) {
			val id = m.id;
			val price = plhE().markets(id).getPrice();
			val size = plhE().markets(id).marketPrices.size();
			val time = plhE().markets(id).getTime();
			finish {
				for (p in 1..(N_PLACES - 1)) {
					async at (Place(p)) {
						val myprice = plhE().markets(id).getPrice();
						val mysize = plhE().markets(id).marketPrices.size();
						val mytime = plhE().markets(id).getTime();
						assert time == mytime : ["time sync failure", time, mytime];
						assert size == mysize : ["size sync failure", size, mysize];
						assert price == myprice  : ["price sync failure", price, myprice];
					}
				}
			}
		}
		Console.OUT.println("#SyncCheck: OK");
	}
}
