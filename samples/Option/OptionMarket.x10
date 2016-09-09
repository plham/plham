package samples.Option;
import x10.util.List;
import x10.util.ArrayList;
import plham.Market;
import plham.Agent;
import plham.Order;

public class OptionMarket extends Market {

	public static struct Kind(id:Long) {}
	public static KIND_CALL_OPTION = Kind(0);   // The right to buy
	public static KIND_PUT_OPTION = Kind(1);    // The right to sell

	public var optionAgentUpdates:List[List[AgentUpdate]] = new ArrayList[List[AgentUpdate]]();

	/** Call or Put **/
	public var kind:Kind;
	public var underlyingMarketId:Long;
	public var strikePrice:Double;
	public var maturityInterval:Long;
	public var riskFreeRate:Double = 0.001; // From Kawakubo (2015)
	public var dividendYield:Double = 0.0; // From Kawakubo (2015)

	public def this() {
	}

	public def getLongName():String {
		return this.name + "-" + getKindName() + "-" + strikePrice + "-" + maturityInterval;
	}

	public def getKindName():String {
		if (this.kind == KIND_CALL_OPTION) {
			return "Call";
		}
		if (this.kind == KIND_PUT_OPTION) {
			return "Put";
		}
		return "Unknown";
	}

	public def isCallOption():Boolean = this.kind == KIND_CALL_OPTION;

	public def isPutOption():Boolean = this.kind == KIND_PUT_OPTION;

	public def getUnderlyingMarket():Market = this.env.markets(underlyingMarketId); 

	public def setUnderlyingMarket(market:Market) = this.underlyingMarketId = market.id;

	public def getStrikePrice():Double = this.strikePrice;

	public def setStrikePrice(strikePrice:Double) = this.strikePrice = strikePrice;

	public def getMaturityInterval():Long = this.maturityInterval;

	public def setMaturityInterval(maturityInterval:Long) = this.maturityInterval = maturityInterval;
	
	/** Return the time to maturity as the number of steps to maturity. */
	public def getTimeToMaturity():Long = maturityInterval - getTime() % maturityInterval;

	/** Return the time to maturity relative to 1.0 as one year, that is used in the Black-Scholes formula. */
	public def getRateToMaturity():Double = getTimeToMaturity() / (getMaturityInterval() + 0.0);

	public def isMaturityTime():Boolean = getTimeToMaturity() == 1;

	public def getNextMaturityTime():Long = getTime() + getTimeToMaturity();

	public def getRiskFreeRate():Double = this.riskFreeRate;

	public def setRiskFreeRate(riskFreeRate:Double):Double = this.riskFreeRate = riskFreeRate;

	public def getDividendYield():Double = this.dividendYield;

	public def setDividendYield(dividendYield:Double):Double = this.dividendYield = dividendYield;

	public def handleAgentUpdate(update:AgentUpdate) {
		super.handleAgentUpdate(update);
		val t = getTime();
		while (optionAgentUpdates.size() <= t) { // TODO
			optionAgentUpdates.add(new ArrayList[AgentUpdate]());
		}
		optionAgentUpdates(t).add(update);
	}

	public def updateMarketPrice(price:Double) {
		super.updateMarketPrice(price);
		updateOptionMarket();
	}

	/**
	 * Closing this option market (then it also gets ready the next session).
	 * 
	 * <p>
	 * <b>CALL OPTION:</b>
	 *   BUYER who bought the right to buy in future.
	 *   SELLER who charged to supply for BUYER if exercised.
	 *   BUYER <i>exercises</i> only if <code>strikePrice &lt; underlyingPrice</code>,
	 *     because BUYER has the right to buy and [easily] sells the underlying;
	 *     then buy cheap and sell expensive.
	 *   Otherwise BUYER <i>abandons</i> the right,
	 *     because no motive to buy both.
	 * <p>
	 * <b>PUT OPTION:</b>
	 *   BUYER who bought the right to sell in future.
	 *   SELLER who changed to supply for BUYER if exercised.
	 *   BUYER <i>exercises</i> only if <code>strikePrice &gt; underlyingPrice</code>,
	 *     because BUYER has the right to sell and [easily] gets the underlying;
	 *     then buy cheap and sell expensive.
	 *   Otherwise BUYER <i>abandons</i> the right,
	 *     because no motive to sell both.
	 */
	public def updateOptionMarket() {
		val underlying = getUnderlyingMarket();
		val underPrice = underlying.getPrice();

		var isValuable:Boolean = false;
		if (isCallOption() && strikePrice < underPrice) { // Having an intrinsic value (= in the money)
			isValuable = true;
		}
		if (isPutOption()  && strikePrice > underPrice) { // Having an intrinsic value (= in the money)
			isValuable = true;
		}
		Console.OUT.println("# [" + (isCallOption() ? "Call" : "Put") + ", " + (isValuable ? "Exercise" : "Abandon") + ", " + getTime() + "]");
		Console.OUT.println("# OptionMarket: " + this.name + ", " + getTimeToMaturity() + ", " + getNextMaturityTime() + ", " + isMaturityTime());

		val T = getTime();
		while (optionAgentUpdates.size() <= T) { // TODO
			optionAgentUpdates.add(new ArrayList[AgentUpdate]());
		}

		if (isMaturityTime()) {
			Console.OUT.println("# MaturityTime " + T);
			if (false) { // TODO: It should be "true" but now set it to "false" for stability of simulations.
				this.getBuyOrderBook().removeAllWhere((Order) => true);
				this.getSellOrderBook().removeAllWhere((Order) => true);
			}
			// TODO: lastMaturityTime
			for (t in Math.max(0, T - maturityInterval + 1)..T) {
				for (update in optionAgentUpdates(t)) {
					val exchangePrice = Math.abs(underPrice - strikePrice);
					val exchangeVolume = Math.abs(update.assetVolumeDelta);
					val cashAmountDelta = Math.abs(exchangePrice * exchangeVolume);
					val assetVolumeDelta = exchangeVolume;
					if (isValuable) {
						// Exercise
						if (update.isBuySide()) {
							val u = new AgentUpdate();
							u.marketId = update.marketId;
							u.agentId = update.agentId;
							u.orderId = update.orderId;
							u.price = strikePrice;
							u.cashAmountDelta = +cashAmountDelta;
							u.assetVolumeDelta = -assetVolumeDelta; // Setoff
							super.handleAgentUpdate(u); // Don't use `this`
						}
						if (update.isSellSide()) {
							val u = new AgentUpdate();
							u.marketId = update.marketId;
							u.agentId = update.agentId;
							u.orderId = update.orderId;
							u.price = strikePrice;
							u.cashAmountDelta = -cashAmountDelta;
							u.assetVolumeDelta = +assetVolumeDelta; // Setoff
							super.handleAgentUpdate(u); // Don't use `this`
						}
					} else {
						// Abandon
					}
				}
				optionAgentUpdates(t).clear();
			}
		}
	}
}
