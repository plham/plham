package plham;
import x10.util.HashMap;
import x10.util.Map;
import x10.util.Random;
import x10.util.Pair;
import plham.util.MultiGeomBrownian;
import plham.util.GraphUtils;

/**
 * A class for fundamental values of multiple markets (assets).
 * This can generate multivariate geometric Brownian motion (MGBM).
 * <p> Calling <code>setup()</code> instantiates MGBM.
 * Just setting the parameters (initials, drifts, volatilities, correlations)
 * does not modify the behavior of MGBM; so call <code>setup()</code> to
 * re-instanciate (<code>setup(true)</code> inherits the current state of MGBM).
 * <p> The <code>initials</code> must be specified (no defaults).
 * On the <code>drafts</code>, <code>volatilities</code>, <code>correlations</code>,
 * their default values are 0.0.
 */
public class Fundamentals {

	static type Key = Pair[Long,Long];

	public var random:Random;
	public var table:Map[Long,Long] = new HashMap[Long,Long](); // Market.id --> GBM internal index
	public var initials:Map[Long,Double] = new HashMap[Long,Double]();
	public var drifts:Map[Long,Double] = new HashMap[Long,Double]();
	public var volatilities:Map[Long,Double] = new HashMap[Long,Double]();
	public var correlations:Map[Pair[Long,Long],Double] = new HashMap[Pair[Long,Long],Double]();

	public def this(random:Random) {
		this.random = random;
	}

	protected def addIndex(id:Long):Long {
		if (table.containsKey(id)) {
			return table(id);
		}
		return table(id) = table.size();
	}

	public def setInitial(market:Market, initial:Double) {
		this.setInitial(market.id, initial);
	}

	public def setInitial(id:Long, initial:Double) {
		addIndex(id);
		this.initials(id) = initial;
	}

	public def setDrift(market:Market, drift:Double) {
		this.setDrift(market.id, drift);
	}

	public def setDrift(id:Long, drift:Double) {
		addIndex(id);
		this.drifts(id) = drift;
	}

	public def setVolatility(market:Market, volatility:Double) {
		this.setVolatility(market.id, volatility);
	}

	public def setVolatility(id:Long, volatility:Double) {
		addIndex(id);
		this.volatilities(id) = volatility;
	}

	public def setCorrelation(market1:Market, market2:Market, correlation:Double) {
		this.setCorrelation(market1.id, market2.id, correlation);
	}

	public def setCorrelation(id1:Long, id2:Long, correlation:Double) {
		addIndex(id1);
		addIndex(id2);
		this.correlations(Key(id1, id2)) = correlation;
		this.correlations(Key(id2, id1)) = correlation;
	}

	public def removeCorrelation(id1:Long, id2:Long) {
		this.correlations.remove(Key(id1, id2));
		this.correlations.remove(Key(id2, id1));
	}
	
	public def get(market:Market):Double = this.get(market.id, market.getFundamentalPrice());

	public def get(id:Long):Double = this.get(id, Double.NaN);

	public def get(id:Long, orElse:Double):Double {
		if (this.table.containsKey(id)) {
			return this.GBM(this.g(id)).get(this.l(id));
		}
		return orElse;
	}

	public def update() {
		for (gbm in this.GBM) {
			gbm.nextBrownian();
		}
	}

	public def setup() {
		this.setup(true);
	}

	public var GBM:Rail[MultiGeomBrownian];
	public var g:Map[Long,Long];
	public var l:Map[Long,Long];

	/* MEMO
	 * The core of MGBM is correlated Gaussian noise.
	 * Not all the markets of a MGBM is necessarily in part of.
	 * If volatility == 0, the market's fundamental is independent of others
	 * (even when its correlations > 0 for some).
	 * Thus simply GeomBrownian for trend.
	 * Or no need to manage if trend == 0 too.
	 * So correlation network analysis, and then decomposed MGBM instances.
	 */
	public def setup(inheritance:Boolean) {
		val nodes = table.keySet();
		val pairs = correlations.keySet();
		val cclist = GraphUtils.getConnectedComponents(nodes, pairs);
		GraphUtils.dump(cclist);

		val g = new HashMap[Long,Long](); // market.id --> group id
		val l = new HashMap[Long,Long](); // market.id --> local index

		var gid:Long;
		var lid:Long;

		gid = 0;
		for (ccitems in cclist) {
			lid = 0;
			for (id in ccitems) {
				g(id) = gid;
				l(id) = lid++;
			}
			gid++;
		}

		val GBM = new Rail[MultiGeomBrownian](cclist.size());
		for (ccitems in cclist) {
			val N = ccitems.size();
			val gbm = new MultiGeomBrownian(random, N);

			val m = new Rail[Long](N); // local index ==> market.id
			for (id in ccitems) {
				m(l(id)) = id;
			}

			for (i in 0..(N - 1)) {
				gbm.s0(i) = this.initials.get(m(i));
			}
			for (i in 0..(N - 1)) {
				gbm.mu(i) = this.drifts.getOrElse(m(i), 0.0);
			}
			for (i in 0..(N - 1)) {
				gbm.sigma(i) = this.volatilities.getOrElse(m(i), 0.0);
			}
			for (i in 0..(N - 1)) {
				for (j in 0..(N - 1)) {
					gbm.cor(i)(j) = this.correlations.getOrElse(Key(m(i), m(j)), 0.0);
					gbm.cor(j)(i) = this.correlations.getOrElse(Key(m(j), m(i)), 0.0);
				}
			}
			for (i in 0..(N - 1)) {
				gbm.cor(i)(i) = 1.0;
			}

			gid = cclist.size(); // Error if ccitems is empty
			for (id in ccitems) {
				gid = g(id); // Use the 1st one (all the same)
				break;
			}
			GBM(gid) = gbm;
		}

		// Copying the internal states.
		if (inheritance && this.GBM != null) {
			for (id in nodes) {
				if (this.g.containsKey(id)) {
					GBM(g(id)).state(l(id)) = this.GBM(this.g(id)).state(this.l(id));
				}
			}
		}

		Console.OUT.println("#Fundamentals.setup() finished");
		Console.OUT.println("# #groups " + GBM.size);
//		Console.OUT.println("# group id " + g);
//		Console.OUT.println("# local index " + l);

		this.GBM = GBM;
		this.g = g;
		this.l = l;
	}

	public static def main(Rail[String]) {
		val random = new Random();
		val N = 4; // # of initial markets
		val m = 2; // # of additional markets

		val id = new Rail[Long](N + m, (i:Long) => i * 10);
		
		val f = new Fundamentals(random);
		for (i in 0..(N - 1)) {
			f.setInitial(id(i), 100 * random.nextDouble() + 100);
			f.setDrift(id(i), 1e-6 * random.nextDouble());
			f.setVolatility(id(i), 1e-3 * random.nextDouble());
			for (j in 0..(N - 1)) {
				if (random.nextDouble() < 0.3) {
					f.setCorrelation(id(i), id(j), random.nextDouble());
				}
			}
		}
		f.setup();

		// SESSION 1

		f.update();
		for (t in 1..1000) {
			for (i in 0..(N + m - 1)) {
				Console.OUT.print(f.get(id(i)) + " ");
			}
			Console.OUT.println();
			f.update();
		}

		// MODIFY PARAMETERS

		for (i in 2..(N - 1)) {
			f.setVolatility(id(i), 1e-3 * random.nextDouble()); // Change volatilities for i = 2,..,N-1
		}

		// ADDITIONAL MARKETS

		for (i in N..(N + m - 1)) {
			f.setInitial(id(i), 100 * random.nextDouble() + 100);
			f.setDrift(id(i), 1e-6 * random.nextDouble());
			f.setVolatility(id(i), 1e-3 * random.nextDouble());
			for (j in 0..(N + m - 1)) {
				if (random.nextDouble() < 0.3) {
					f.setCorrelation(id(i), id(j), random.nextDouble());
				} else if (random.nextDouble() < 0.3) {
					f.removeCorrelation(id(i), id(j));
				}
			}
		}
		f.setup();

		// SESSION 2

		f.update();
		for (t in 1..1000) {
			for (i in 0..(N + m - 1)) {
				Console.OUT.print(f.get(id(i)) + " ");
			}
			Console.OUT.println();
			f.update();
		}
	}
}
