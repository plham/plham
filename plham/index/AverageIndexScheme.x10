package plham.index;
import x10.util.List;
import plham.Market;

public abstract class AverageIndexScheme extends IndexScheme {

	public static MARKET_PRICE = (market:Market) => market.getPrice();
	public static FUNDAMENTAL_PRICE = (market:Market) => market.getFundamentalPrice();

	public var get:(market:Market)=>Double;
	public var indexDivisor:Double;

	public def this(get:(market:Market)=>Double) {
		this.get = get;
		this.indexDivisor = 1.0;
	}

	public def getIndex(markets:List[Market]):Double {
		var sum:Double = 0.0;
		for (market in markets) {
			sum += this.getWeight(market) * this.getPrice(market);
		}
		val meanPrice = sum / markets.size();
		return meanPrice / this.indexDivisor;
	}

	public def getIndex(markets:List[Market], components:List[Long]):Double {
		var sum:Double = 0.0;
		for (i in components) {
			val market = markets(i);
			sum += this.getWeight(market) * this.getPrice(market);
		}
		val meanPrice = sum / components.size();
		return meanPrice / this.indexDivisor;
	}

	public def getPrice(market:Market):Double {
		return this.get(market);
	}

	public def setIndexDivisor(initialPrice:Double, basePrice:Double) {
		this.indexDivisor = basePrice / initialPrice;
	}
}
