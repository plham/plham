package samples.Option.pricer;
import samples.Option.util.BlackScholes;

public class BlackScholesOptionPricer implements OptionPricer {

	/**
	 * Estimate the call option price (premium).
	 */
	public def premiumCall(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double)
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
