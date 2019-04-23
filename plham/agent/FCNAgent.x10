package plham.agent;
import x10.util.ArrayList;
import x10.util.Indexed;
import x10.util.List;
import x10.util.Random;
import plham.Agent;
import plham.Market;
import plham.Order;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.util.RandomHelper;

/**
 * An order decision mechanism proposed in Chiarella & Iori (2004).
 * It employs two simple margin-based random tradings.
 * 
 * Given an expected future price <it>p</it>, submit an order of price
 * <ul>
 * <li> <code>"fixed"</code> :  <it>p</it> (1 &pm; <it>k</it>)  where  0 ≦ <it>k</it> ≦ 1
 * <li> <code>"normal"</code> : <it>p</it> + N(0, <it>k</it>)   where  <it>k</it> > 0
 * </ul>
 */
public class FCNAgent extends Agent {

	/** The fundamental weight of this fcn-agent. */
	public var fundamentalWeight:Double;
	/** The chartist weight of this fcn-agent. */
	public var chartWeight:Double;
	/** The noise weight of this fcn-agent. */
	public var noiseWeight:Double;
	/** The standard deviation of noise. */
	public var noiseScale:Double;
	/** The time window size this fcn-agent use in chartist analysis. */
	public var timeWindowSize:Long;
	/** The fcn-agent submits order if and only if the market price exceeds(falls) his prediction by <code>orderMargin</code>. */
	public var orderMargin:Double;
	/* XXX: what is it? */
	public var isChartFollowing:Boolean = false;
	/** The fcn-agent presumes that the market price converges in <code>meanReversionTime</code>. */
	public var meanReversionTime:Long;

	public static MARGIN_FIXED = 0; //"FixedMargin";
	public static MARGIN_NORMAL = 1; //"NormalMargin";
	/** <code>marginType</code> specifies which margin type is used. 0 is for Chiarella&Iori's fixed margin, 1 is for Mizuta's normal margin.*/
	public var marginType:Long;

	/** 
	 * The constructor of this class.
	 * Note that <code>FCNAgent</code>'s initialization is completed by the initializer registered in the simulator. 
	 * @see plham.agent.FCNAgent.register
	 */
	public def this(id:Long, name:String, random:Random) = super(id, name, random);

	/**
	 * Registers the initializer of the <code>FCNAgent</code> to the given simulator.
	 */
	public static def register(sim:Simulator):void {
		val className = "FCNAgent";
		sim.addAgentInitializer(className,
			(
				id:Long,
				name:String, 
				random:Random,
				json:JSON.Value
			) => {
				return new FCNAgent(id, name, random).setup(json, sim);
			}
		);
	}

	/**
	 * Sets up this FCNAgent object after constructor called.
	 * This method called by the FCNAgent's initializer.
	 */
	public def setup(json:JSON.Value, sim:Simulator):FCNAgent {
		val jsonrandom = new JSONRandom(getRandom());
		super.setup(json, sim); // first, setup this agent as plham.Agent. and then, setup as plham.agent.FCNAgent;
		val MARGIN_TYPES = JSON.parse(
			"{'fixed': " + FCNAgent.MARGIN_FIXED + "," +
			"'normal': " + FCNAgent.MARGIN_NORMAL +
		"}");
		this.fundamentalWeight = jsonrandom.nextRandom(json("fundamentalWeight"));
		this.chartWeight = jsonrandom.nextRandom(json("chartWeight"));
		this.noiseWeight = jsonrandom.nextRandom(json("noiseWeight"));
		this.isChartFollowing = (jsonrandom.nextDouble() < 1.0); // 100%
		this.noiseScale = jsonrandom.nextRandom(json("noiseScale"));
		this.timeWindowSize = jsonrandom.nextRandom(json("timeWindowSize")) as Long;
		this.orderMargin = jsonrandom.nextRandom(json("orderMargin"));
		this.marginType = MARGIN_TYPES(json("marginType", "fixed")).toLong();
		if(json.has("meanReversionTime")){
			this.meanReversionTime = jsonrandom.nextRandom(json("meanReversionTime")) as Long;
		}else{
			this.meanReversionTime = this.timeWindowSize;
		}
		return this;
	}

	/**
	 * Returns the given x is a finit real number.
	 * Returns true if and only if <code>x</code> is not NaN and not infinity(positive or negative). Otherwise returns false.
	 */
	public static def isFinite(x:Double) {
		return !x.isNaN() && !x.isInfinite();
	}

	/**
	 * Submits orders to the given markets.
	 */
	public def submitOrders(markets:List[Market]):List[Order] {
		val orders = new ArrayList[Order]();
		for (market in markets) {
			if (this.isMarketAccessible(market)) {
				orders.addAll(this.submitOrders(market));
			}
		}
		return orders;
	}

	protected def submitOrders(market:Market):List[Order] {
		val orders = new ArrayList[Order]();
		if (!this.isMarketAccessible(market)) {
			return orders;
		}

		val random = new RandomHelper(getRandom());

		val fcRatio = (1.0 + this.fundamentalWeight) / (1.0 + this.chartWeight);

		/* 現在のステップ t */
		val t = market.getTime();

		/* Chartist の観察する時系列窓のサイズ */
		val timeWindowSize = Math.min(t, this.timeWindowSize);
		assert timeWindowSize >= 0 : "timeWindowSize >= 0";

		/* market.getFundamentalPrice(t) : ステップ t の理論価格 */
		/* market.getPrice(t)      : ステップ t の市場価格 */

		assert this.fundamentalWeight >= 0.0 : "fundamentalWeight >= 0.0";
		assert this.chartWeight >= 0.0 : "chartWeight >= 0.0";
		assert this.noiseWeight >= 0.0 : "noiseWeight >= 0.0";
		
		/* 式 (6) : ファンダメンタル分析項 */
		val fundamentalScale = 1.0 / Math.max(meanReversionTime, 1);
		val fundamentalLogReturn = fundamentalScale * Math.log(market.getFundamentalPrice(t) / market.getPrice(t));
		assert isFinite(fundamentalLogReturn) : "isFinite(fundamentalLogReturn)";

		/* 式 (7) : テクニカル分析項（チャート） */
		val chartScale = 1.0 / Math.max(timeWindowSize, 1);
		val chartMeanLogReturn = chartScale * Math.log(market.getPrice(t) / market.getPrice(t - timeWindowSize));
		assert isFinite(chartMeanLogReturn) : "isFinite(chartMeanLogReturn)";

		/* 式 (8) : ノイズ項 */
		val noiseLogReturn = 0.0 + this.noiseScale * random.nextGaussian();
		assert isFinite(noiseLogReturn) : "isFinite(noiseLogReturn)";
		
		/* 式 (5) : 期待リターン */
		val expectedLogReturn = (1.0 / (this.fundamentalWeight + this.chartWeight + this.noiseWeight))
				* (this.fundamentalWeight * fundamentalLogReturn
					+ this.chartWeight * chartMeanLogReturn * (this.isChartFollowing ? +1 : -1)
					+ this.noiseWeight * noiseLogReturn);
		assert isFinite(expectedLogReturn) : "isFinite(expectedLogReturn)";
		
		/* 式 (9) : 将来の期待価格  */
		val expectedFuturePrice = market.getPrice(t) * Math.exp(expectedLogReturn * timeWindowSize);
		assert isFinite(expectedFuturePrice) : "isFinite(expectedFuturePrice)";

		if (this.marginType == MARGIN_FIXED) {
			/* This is from Chiarella & Iori (2002) */
			/* 注文の値段を決めるときに使うマージン */
			assert 0.0 <= this.orderMargin && this.orderMargin <= 1.0;

			var orderPrice:Double = 0.0;
			var orderVolume:Long = 1;

			if (expectedFuturePrice > market.getPrice(t)) {
				/* 式 (10) : 買い注文 */
				orderPrice = expectedFuturePrice * (1 - this.orderMargin);
				orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, market, orderPrice, orderVolume, timeWindowSize));
			}
			if (expectedFuturePrice < market.getPrice(t)) {
				/* 式 (11) : 売り注文 */
				orderPrice = expectedFuturePrice * (1 + this.orderMargin);
				orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, market, orderPrice, orderVolume, timeWindowSize));
			}
			assert orderPrice >= 0.0 : ["orderPrice >= 0.0", orderPrice];
			assert orderVolume >= 0 : ["orderVolume >= 0", orderVolume];
		}
		if (this.marginType == MARGIN_NORMAL) {
			/* This is from Mizuta etal (2014) */
			/* 注文の値段を決めるときに使うマージン */
			assert this.orderMargin >= 0.0;

			var orderPrice:Double = expectedFuturePrice + random.nextGaussian() * this.orderMargin;
			var orderVolume:Long = 1;
			assert orderPrice >= 0.0 : ["orderPrice >= 0.0", orderPrice];
			assert orderVolume >= 0 : ["orderVolume >= 0", orderVolume];

			if (expectedFuturePrice > orderPrice) {
				/* 式 (10) : 買い注文 */
				orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, market, orderPrice, orderVolume, timeWindowSize));
			}
			if (expectedFuturePrice < orderPrice) {
				/* 式 (11) : 売り注文 */
				orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, market, orderPrice, orderVolume, timeWindowSize));
			}
		}
		return orders;
	}
}
