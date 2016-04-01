package plham.agent;
import x10.util.ArrayList;
import x10.util.List;
import plham.Agent;
import plham.Market;
import plham.Order;

public class NullAgent extends Agent {
	
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
	
	public def isMarketAccessible(market:Market):Boolean {
		return true;
	}
	
	public def setMarketAccessible(market:Market) {
	}

	public def getCashAmount():Double {
		val ENOUGH_CASH = 1e+10;
		return ENOUGH_CASH;
	}
	
	public def setCashAmount(cashAmount:Double) {
	}
	
	public def updateCashAmount(delta:Double) {
	}

	public def getAssetVolume(market:Market):Long {
		val ENOUGH_VOLUME = 1e+10;
		return ENOUGH_VOLUME as Long;
	}
	
	public def setAssetVolume(market:Market, assetVolume:Long) {
	}
	
	public def updateAssetVolume(market:Market, delta:Long) {
	}
}
