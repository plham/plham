package samples.Option.pricer;
import samples.Option.util.BlackScholes;

public class BlackScholesOptionPricer implements OptionPricer {

	/**
	 * Estimate the call option price (premium).
	 */
	public def premiumCall(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double)
		val random = this.random;
		val g = new Gaussian(random);

		val dt = this.maturityTime / nsteps;

		val r = riskFreeRate;
		val sigma = volatility;

		var sum:Double = 0.0;
		for (i in 0..(nsamples - 1)) {
			var price:Double = this.initialPrice;
			for (t in 0..(nsteps - 1)) {
				price += price * r * dt + price * g.nextGaussian() * sigma * Math.sqrt(dt);
			}
			sum += Math.max(price - this.strikePrice, 0.0);
		}
		return Math.exp(-r * this.maturityTime) * (sum / nsamples);
		= BlackScholes.premiumCall(underlyingPrice, strikePrice, volatility, timeToMaturity, riskFreeRate, dividendYield);

	/**
	 * Estimate the put option price (premium).
	 */
	public def premiumPut(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double)
		= BlackScholes.premiumPut(underlyingPrice, strikePrice, volatility, timeToMaturity, riskFreeRate, dividendYield);

	/**
	 * Estimate the greek delta.
	 */
	public def deltaCall(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double)
		= BlackScholes.deltaCall(underlyingPrice, strikePrice, volatility, timeToMaturity, riskFreeRate, dividendYield);

	/**
	 * Estimate the greek delta.
	 */
	public def deltaPut(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double)
		= BlackScholes.deltaPut(underlyingPrice, strikePrice, volatility, timeToMaturity, riskFreeRate, dividendYield);

	/**
	 * Estimate the implied volatility.
	 */
	public def impliedVolatilityCall(premium:Double, underlyingPrice:Double, strikePrice:Double, volatilityGuess:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double)
		= BlackScholes.impliedVolatilityCall(premium, underlyingPrice, strikePrice, volatilityGuess, timeToMaturity, riskFreeRate, dividendYield);

	/**
	 * Estimate the implied volatility.
	 */
	public def impliedVolatilityPut(premium:Double, underlyingPrice:Double, strikePrice:Double, volatilityGuess:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double)
		= BlackScholes.impliedVolatilityPut(premium, underlyingPrice, strikePrice, volatilityGuess, timeToMaturity, riskFreeRate, dividendYield);
}
