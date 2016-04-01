package plham.index;
import plham.Market;

public class PriceWeightedIndexScheme extends AverageIndexScheme {

	public def this(get:(market:Market)=>Double) {
		super(get);
	}

	public def getWeight(market:Market):Double {
		return 1.0;
	}
}
