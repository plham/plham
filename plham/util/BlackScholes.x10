package plham.util;
import x10.util.Random;
import cassia.util.random.Gaussian;

public class BlackScholes {

	public var random:Random;
	public var initialPrice:Double;
	public var strikePrice:Double;
	public var riskFreeRate:Double;
	public var volatility:Double;
	public var maturityTime:Double; // time to maturity.

	public def this(random:Random, initialPrice:Double, strikePrice:Double, riskFreeRate:Double, volatility:Double, maturityTime:Double) {
		this.random = random;
		this.initialPrice = initialPrice;
		this.strikePrice = strikePrice;
		this.riskFreeRate = riskFreeRate;
		this.volatility = volatility;
		this.maturityTime = maturityTime;
	}

	public def compute(nsamples:Long, nsteps:Long):Double {
		val random = this.random;
		val g = new Gaussian(random);

		val r = this.riskFreeRate;
		val sigma = this.volatility;
		val dt = this.maturityTime / nsteps;

		var sum:Double = 0.0;
		for (i in 0..(nsamples - 1)) {
			var price:Double = this.initialPrice;
			for (t in 0..(nsteps - 1)) {
				price += price * r * dt + price * g.nextGaussian() * sigma * Math.sqrt(dt);
			}
			sum += Math.max(price - this.strikePrice, 0.0);
		}
		return Math.exp(-r * this.maturityTime) * (sum / nsamples);
	}

	public static def main(Rail[String]) {
		val random = new Random(); // MEMO: main()
		val bs = new BlackScholes(random, 100.0, 100.0, 0.1, 0.3, 3);
		Console.OUT.println("Theory: 33.6044837628");
		Console.OUT.println("Estimated: " + bs.compute(1000, 100));
	}
}
