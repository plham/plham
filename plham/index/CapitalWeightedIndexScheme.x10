package plham.index;
import plham.Market;

public class CapitalWeightedIndexScheme extends AverageIndexScheme {

	public def this(get:(market:Market)=>Double) {
		super(get);
	}

	public def getWeight(market:Market):Double {
		return market.getOutstandingShares();
	}
}
