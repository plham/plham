package plham.index;
import x10.util.List;
import plham.Market;

public abstract class IndexScheme {

	public abstract def getIndex(markets:List[Market]):Double;

	public abstract def getIndex(markets:List[Market], components:List[Long]):Double;

	public abstract def getWeight(market:Market):Double;

	public abstract def getPrice(market:Market):Double;
}
