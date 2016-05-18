package plham.agent;
import x10.util.ArrayList;
import x10.util.List;
import plham.Agent;
import plham.Market;
import plham.Order;

public class NullAgent extends Agent {
	
	static ENOUGH_CASH = 1e+10;
	static ENOUGH_VOLUME = 1e+10 as Long;

	public def this() {
	}

	public def this(id:Long) {
		this.id = id;
	}

	public def submitOrders(markets:List[Market]):List[Order] {
		val orders = new ArrayList[Order]();
		return orders;
	}
	
	public def submitOrders(market:Market):List[Order] {
		val orders = new ArrayList[Order]();
		return orders;
	}
	
	public def isMarketAccessible(id:Long) = true;
	
	public def setMarketAccessible(id:Long) = 0;

	public def getCashAmount() = ENOUGH_CASH;
	
	public def setCashAmount(cashAmount:Double) = ENOUGH_CASH;
	
	public def updateCashAmount(delta:Double) = ENOUGH_CASH;

	public def getAssetVolume(id:Long) = ENOUGH_VOLUME;
	
	public def setAssetVolume(id:Long, assetVolume:Long) = ENOUGH_VOLUME;
	
	public def updateAssetVolume(id:Long, delta:Long) = ENOUGH_VOLUME;
}
