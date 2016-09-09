package samples.Option.util;
import plham.util.Newton;

public class BlackScholes {

	public static class Normal {

		/**
		 * The normal probability density of mu = 0 and sigma = 1.
		 * Imported from Financial Numerical Recipes, p.230 (Code A.1).
		 */
		public static def pdf(z:Double):Double {
			return (1.0 / Math.sqrt(2.0 * Math.PI)) * Math.exp(-0.5 * z * z);
		}

		/**
		 * The normal cumulative distribution of mu = 0 and sigma = 1.
		 * Imported from Financial Numerical Recipes, p.231 (Code A.2).
		 */
		public static def cdf(z:Double):Double {
			if (z > +6.0) { return 1.0; } // This guards against overflow
			if (z < -6.0) { return 0.0; } // This guards against overflow
			val b1 = 0.31938153;
			val b2 = -0.356563782;
			val b3 = 1.781477937;
			val b4 = -1.821255978;
			val b5 = 1.330274429;
			val p = 0.2316419;
			val c2 = 0.3989423;

			val a = Math.abs(z);
			val t = 1.0 / (1.0 + a * p);
			val b = c2 * Math.exp((-z) * (z / 2.0));
			var n:Double;
			n = ((((b5 * t + b4) * t + b3) * t + b2) * t + b1) * t;
			n = 1.0 - b * n;
			if (z < 0.0) {
				n = 1.0 - n;
			}
			return n;
		}
	}

	/**
	 * The Black-Scholes' d1 term.
	 */
	public static def d1(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double {
		val S = underlyingPrice;
		val K = strikePrice;
		val sigma = volatility;
		val T = timeToMaturity;
		val r = riskFreeRate;
		val q = dividendYield;

		return (Math.log(S / K) + (r - q + sigma * sigma / 2) * T) / (sigma * Math.sqrt(T));
	}

	/**
	 * The Black-Scholes' d2 term.
	 */
	public static def d2(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double {
		val S = underlyingPrice;
		val K = strikePrice;
		val sigma = volatility;
		val T = timeToMaturity;
		val r = riskFreeRate;
		val q = dividendYield;

		return (Math.log(S / K) + (r - q - sigma * sigma / 2) * T) / (sigma * Math.sqrt(T));
	}

	/**
	 * Estimate the call option price (premium).
	 */
	public static def premiumCall(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double {
		val S = underlyingPrice;
		val K = strikePrice;
		val sigma = volatility;
		val T = timeToMaturity;
		val r = riskFreeRate;
		val q = dividendYield;

		if (T <= 0) {
			return Math.max(0, S - K);
		}
		val d1 = d1(S, K, sigma, T, r, q);
		val d2 = d2(S, K, sigma, T, r, q);
		return + S * Math.exp(-q * T) * Normal.cdf( d1) - K * Math.exp(-r * T) * Normal.cdf( d2);
	}

	/**
	 * Estimate the put option price (premium).
	 */
	public static def premiumPut(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double {
		val S = underlyingPrice;
		val K = strikePrice;
		val sigma = volatility;
		val T = timeToMaturity;
		val r = riskFreeRate;
		val q = dividendYield;

		if (T <= 0) {
			return Math.max(0, K - S);
		}
		val d1 = d1(S, K, sigma, T, r, q);
		val d2 = d2(S, K, sigma, T, r, q);
		return - S * Math.exp(-q * T) * Normal.cdf(-d1) + K * Math.exp(-r * T) * Normal.cdf(-d2);
	}

	/**
	 * Estimate the greek delta.
	 */
	public static def deltaCall(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double {
		val S = underlyingPrice;
		val K = strikePrice;
		val sigma = volatility;
		val T = timeToMaturity;
		val r = riskFreeRate;
		val q = dividendYield;
		
		val d1 = d1(S, K, sigma, T, r, q);
		return +Normal.cdf(+d1);
	}

	/**
	 * Estimate the greek delta.
	 */
	public static def deltaPut(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double {
		val S = underlyingPrice;
		val K = strikePrice;
		val sigma = volatility;
		val T = timeToMaturity;
		val r = riskFreeRate;
		val q = dividendYield;
		
		val d1 = d1(S, K, sigma, T, r, q);
		return -Normal.cdf(-d1);
	}

	/**
	 * Estimate the implied volatility.
	 */
	public static def impliedVolatilityCall(premium:Double, underlyingPrice:Double, strikePrice:Double, volatilityGuess:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double {
		val S = underlyingPrice;
		val K = strikePrice;
		val sigma0 = volatilityGuess;
		val T = timeToMaturity;
		val r = riskFreeRate;
		val q = dividendYield;

		val f = (sigma:Double) => premium - premiumCall(S, K, sigma, T, r, q);
		try {
			return Math.max(0.0, Newton.optimize(f, sigma0));
		} catch (Exception) {
			return 0.0; // Because the function premiumCall() is monotonically
			// increasing of sigma, the bottom is given by sigma = 0.
			// This means inexact solution, but the best approximate.
		}
	}

	/**
	 * Estimate the implied volatility.
	 */
	public static def impliedVolatilityPut(premium:Double, underlyingPrice:Double, strikePrice:Double, volatilityGuess:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double {
		val S = underlyingPrice;
		val K = strikePrice;
		val sigma0 = volatilityGuess;
		val T = timeToMaturity;
		val r = riskFreeRate;
		val q = dividendYield;

		val f = (sigma:Double) => premium - premiumPut(S, K, sigma, T, r, q);
		try {
			return Math.max(0.0, Newton.optimize(f, sigma0));
		} catch (Exception) {
			return 0.0; // Because the function premiumCall() is monotonically
			// increasing of sigma, the bottom is given by sigma = 0.
			// This means inexact solution, but the best approximate.
		}
	}

	public static def main(Rail[String]) {
		if (false) {
			// Comparison (in R)
			// z = seq(-8, 8, by=0.2)
			// plot(z, dnorm(z), type='l', col='red', ylim=c(0,1))
			// lines(z, pnorm(z), type='l', col='green')
			for (var z:Double = -8.0; z <= 8.0; z += 0.2) {
				Console.OUT.println(z + " " + Normal.pdf(z) + " " + Normal.cdf(z));
			}
		}
		if (true) {
			// An online textbook, see http://investexcel.net/implied-volatility-vba
			Console.OUT.println("Textbook says: premiumCall: 0.2404, premiumPut: 0.5364");
			Console.OUT.println("Our results:");
			Console.OUT.println("  premiumCall: " + impliedVolatilityCall(15, 100, 90, /*vol-guess*/0.7, 1, 0.02, 0.015));
			Console.OUT.println("  premiumPut:  " + impliedVolatilityPut(15, 100, 90, /*vol-guess*/0.7, 1, 0.02, 0.015));
		}
	}
}
