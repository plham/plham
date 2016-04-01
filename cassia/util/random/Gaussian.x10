package cassia.util.random;
import x10.util.Random;

public class Gaussian {
	
	var state:Boolean;
	var g:Double;
	var random:Random;
	
	public def this(random:Random) {
		this.state = false;
		this.g = -1;
		this.random = random;
	}
	
	public def nextGaussian():Double {
		if (state) {
			state = false;
			return this.g;
		} else {
			state = true;
			var v1:Double;
			var v2:Double;
			var s:Double;
			do {
				v1 = 2.0 * random.nextDouble() - 1.0;
				v2 = 2.0 * random.nextDouble() - 1.0;
				s = v1 * v1 + v2 * v2;
			} while (s >= 1.0);
			
			var norm:Double = Math.sqrt(-2.0 * Math.log(s) / s);
			this.g = v2 * norm;
			return v1 * norm;
		}
	}
	
	public def nextGaussian(mu:Double, sigma:Double) {
		return mu + sigma * this.nextGaussian();
	}
	
	public static def main(Rail[String]) {
		val std = 0.01;
		val g = new Gaussian(new Random()); // MEMO: main()
		for (val t in 1..1000) {
			Console.OUT.println(g.nextGaussian() * std);
		}
	}
}
