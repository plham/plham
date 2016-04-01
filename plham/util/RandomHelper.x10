package plham.util;
import x10.util.Random;
import cassia.util.random.Gaussian;

/**
 * A helper class adding more utilities to Random.
 */
public class RandomHelper {
	
	public var random:Random;
	public var g:Gaussian;

	public def this(random:Random) {
		this.random = random;
		this.g = new Gaussian(random);
	}

	public def nextBoolean() = this.random.nextBoolean();

	public def nextBoolean(p:Double) = this.random.nextDouble() < p;

	public def nextDouble() = this.random.nextDouble();

	public def nextDouble(max:Double) = this.random.nextDouble() * max;

	public def nextFloat() = this.random.nextFloat();

	public def nextFloat(max:Float) = this.random.nextFloat() * max;

	public def nextInt(max:Int) = this.random.nextInt(max);

	public def nextLong(max:Long) = this.random.nextLong(max);

	public def nextGaussian() = this.g.nextGaussian(); // Java compatible

	/**
	 * Get a sample from a uniform distribution between <code>min</code> and <code>max</code>.
	 */
	public def nextUniform(min:Double, max:Double):Double {
		return this.nextDouble() * (max - min) + min;
	}

	/**
	 * Get a sample from a normal distribution, whose mean <code>mu</code> and variance <code>sigma</code>^2.
	 */
	public def nextNormal(mu:Double, sigma:Double):Double {
		return mu + this.nextGaussian() * sigma;
	}

	/**
	 * Get a sample from an exponential distribution, whose expected value is <code>lambda</code>.
	 * Cf: the standard notation may prefer the expected value to be <code>1 / lambda</code>,
	 * but here it is <code>lambda</code> so lambda can take even zero.
	 */
	public def nextExponential(lambda:Double):Double {
		return lambda * -Math.log(this.nextDouble());
	}

	public static def main(Rail[String]) {
		val random = new RandomHelper(new Random()); // MEMO: main()

		val n = 100;
		val U = new Rail[Long](n);
		val N = new Rail[Long](n);
		val E = new Rail[Long](n);
		
		for (t in 1..1000000) {
			val x = random.nextUniform(0, n);
			val i = x as Long;
			U(i) = U(i) + 1;
		}
		for (t in 1..1000000) {
			val x = random.nextNormal(0, 1);
			val i = Math.min(Math.max((x + 50) as Long, 0), 99);
			N(i) = N(i) + 1;
		}
		for (t in 1..1000000) {
			val x = random.nextExponential(10);
			val i = Math.min(Math.max(x as Long, 0), 99);
			E(i) = E(i) + 1;
		}
		for (i in 0..(n - 1)) {
			Console.OUT.println(i + " " + U(i) + " " + N(i) + " " + E(i));
		}
	}
}
