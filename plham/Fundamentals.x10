package plham;
import x10.util.HashMap;
import x10.util.Map;
import x10.util.Random;
import plham.util.MultiGeomBrownian;

/**
 * A class for fundamental values of multiple markets (assets).
 * This can generate multivariate geometric Brownian motion.
 */
public class Fundamentals {

	public var g:MultiGeomBrownian;
	public var table:Map[String,Long]; // Market.name --> GBM internal index

	public def this(random:Random, table:HashMap[String,Long], dim:Long) {
		this.g = new MultiGeomBrownian(random, dim);
		this.table = table;
	}

	public def getInitial(market:Market):Double {
		val i = this.table(market.name);
		return this.g.s0(i);
	}

	public def setInitial(market:Market, initial:Double) {
		this.setInitial(market.name, initial);
	}

	public def setInitial(name:String, initial:Double) {
		val i = this.table(name);
		this.g.s0(i) = initial;
	}

	public def setDrift(market:Market, drift:Double) {
		this.setDrift(market.name, drift);
	}

	public def setDrift(name:String, drift:Double) {
		val i = this.table(name);
		this.g.mu(i) = drift;
	}

	public def setVolatility(market:Market, volatility:Double) {
		this.setVolatility(market.name, volatility);
	}

	public def setVolatility(name:String, volatility:Double) {
		val i = this.table(name);
		this.g.sigma(i) = volatility;
	}

	public def setCorrelation(market1:Market, market2:Market, correlation:Double) {
		this.setCorrelation(market1.name, market2.name, correlation);
	}

	public def setCorrelation(name1:String, name2:String, correlation:Double) {
		val i = this.table(name1);
		val j = this.table(name2);
		this.g.cor(i)(j) = correlation;
		this.g.cor(j)(i) = correlation;
	}
	
	public def get(market:Market):Double {
		val i = this.table(market.name);
		return this.g.get(i);
	}

	public def update() {
		this.g.nextBrownian();
	}
}
