package plham.event;
import plham.Market;
import plham.Fundamentals;

/**
 * This suddently changes the fundamental price (just changing it).
 */
public class FundamentalPriceShock implements Market.MarketEvent {

	public static NO_TIME_LENGTH = Long.MAX_VALUE / 2; // To avoid n + infinity.

	public var marketId:Long;
	public var triggerTime:Long;
	public var priceChangeRate:Double;
	public var shockTimeLength:Long;

	public def this() {
		this.shockTimeLength = NO_TIME_LENGTH;
	}

	public def update(market:Market) {
		assert this.marketId == market.id;
		val t = market.getTime();
		if (t >= this.triggerTime && t <= this.triggerTime + this.shockTimeLength) {
			market.fundamentalPrices(t) *= (1 + this.priceChangeRate);
		}
	}
}
