package plham;
import x10.util.ArrayList;
import x10.util.List;

/**
 * For system use only.
 */
public class Env {

	public static DEBUG = 0;

	public static def getenvOrElse(name:String, orElse:String):String {
		val value = System.getenv(name);
		if (value == null) {
			return orElse;
		}
		return value;
	}

    public var localAgents:List[Agent];
	public var agents:List[Agent]; // MEMO TT it has to be val???
	public var markets:List[Market];
    public var orders:List[List[Order]];

	public var normalAgents:List[Agent];
	public var hifreqAgents:List[Agent];
    
    public var marketsF:MarketsFlat;

	public def this() {
		this.agents = new ArrayList[Agent]();
		this.markets = new ArrayList[Market]();
        this.orders = new ArrayList[List[Order]]();
	}

    public def addOrders(orders:List[List[Order]]) { // TODO TK should use more efficient data str
        atomic { this.orders.addAll(orders);} 
    }
    public def initMarketsF(size:Long) {
    	this.marketsF = new MarketsFlat(size);
    }
    public def prepareMarketsF() {
    	marketsF.prepareMarketInfo(markets);
    	return marketsF;
    }
    public def receiveMarketsF(mflat:MarketsFlat, diffPass:Boolean) {
    	this.marketsF=mflat;
    	if(diffPass) mflat.receiveMarketInfo(markets);
    }

	public static struct MarketsFlat {

		public val _isRunningF:Rail[Boolean];
		public val marketPricesF:Rail[Double];
	//    public val marketReturnsF:Rail[Double];
		public val fundamentalPricesF:Rail[Double];
	//    public val fundamentalReturnsF:Rail[Double];
		
	//    public val lastExecutedPricesF:Rail[Double];
	//    public val buyOrdersCountsF:Rail[Long];
	//    public val sellOrdersCountsF:Rail[Long];
	//    public val executedOrdersCountsF:Rail[Long];

		public val timeF:Rail[Long];
		
		public def this(size:Long) {
			_isRunningF = new Rail[Boolean](size);
			marketPricesF =new Rail[Double](size);
	//        marketReturnsF = new Rail[Double](size);
			fundamentalPricesF  = new Rail[Double](size);
	//        fundamentalReturnsF = new Rail[Double](size);
	//        lastExecutedPricesF = new Rail[Double](size);
	//        buyOrdersCountsF = new Rail[Long](size);
	//        sellOrdersCountsF = new Rail[Long](size);
	//        executedOrdersCountsF = new Rail[Long](size);
			timeF = new Rail[Long](size);
		}

		public def prepareMarketInfo(markets:List[Market]) {
			var i:Long =0l; 
			for(m in markets) {
				_isRunningF(i) = m._isRunning;
				marketPricesF(i) =m.marketPrices.getLast();
	//        	marketReturnsF(i) = m.marketReturns.getLast();
				fundamentalPricesF(i)  = m.fundamentalPrices.getLast();
	//        	fundamentalReturnsF(i) = m.fundamentalReturns.getLast();
	//        	lastExecutedPricesF(i) = m.lastExecutedPrices.getLast();
	//        	buyOrdersCountsF(i) = m.buyOrdersCounts.getLast();
	//        	sellOrdersCountsF(i) = m.sellOrdersCounts.getLast();
	//        	executedOrdersCountsF(i) = m.executedOrdersCounts.getLast();
	//			timeF(i) = m.time;
				i++;
			}
		}
		public def receiveMarketInfo(markets:List[Market]) {
			var i:Long =0l; 
			for(m in markets) {
				m._isRunning = _isRunningF(i);
				m.marketPrices.add(marketPricesF(i));
	//    		m.marketReturns.add(marketReturnsF(i));
				m.fundamentalPrices.add(fundamentalPricesF(i));
	//    		m.fundamentalReturns.add(fundamentalReturnsF(i));
	//    		m.lastExecutedPrices.add(lastExecutedPricesF(i));
	//    		m.buyOrdersCounts.add(buyOrdersCountsF(i));
	//    		m.sellOrdersCounts.add(sellOrdersCountsF(i));
	//    		m.executedOrdersCounts.add(executedOrdersCountsF(i));
	//			m.time = timeF(i);
	//			m.check();
				m.updateTime();
				i++;
			}
		}
	}
}
