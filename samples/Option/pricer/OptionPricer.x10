package samples.Option.pricer;

public interface OptionPricer {

	/**
	 * Estimate the call option price (premium).
	 */
	public def premiumCall(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double;

	/**
	 * Estimate the put option price (premium).
	 */
	public def premiumPut(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double;

	/**
	 * Estimate the greek delta.
	 */
	public def deltaCall(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double;

	/**
	 * Estimate the greek delta.
	 */
	public def deltaPut(underlyingPrice:Double, strikePrice:Double, volatility:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double;

	/**
	 * Estimate the implied volatility.
	 */
	public def impliedVolatilityCall(premium:Double, underlyingPrice:Double, strikePrice:Double, volatilityGuess:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double;

	/**
	 * Estimate the implied volatility.
	 */
	public def impliedVolatilityPut(premium:Double, underlyingPrice:Double, strikePrice:Double, volatilityGuess:Double, timeToMaturity:Double, riskFreeRate:Double, dividendYield:Double):Double;
}
