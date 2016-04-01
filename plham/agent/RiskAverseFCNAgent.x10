package plham.agent;
import x10.util.ArrayList;
import x10.util.List;
import plham.Agent;
import plham.Market;
import plham.Order;
import plham.util.Statistics;
import plham.util.Brent;
import plham.util.RandomHelper;

/**
 * An order decision mechanism proposed in Chiarella, Iori, &amp; Perello (2009).
 * It employs absolute constant risk aversion (CARA) and is restricted to make
 * no debt and no short selling.
 */
public class RiskAverseFCNAgent extends FCNAgent {

	public var riskAversionConstant:Double; // riskAverseness * (yF + 1) / (yC + 1)

	public def submitOrders(market:Market):List[Order] {

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
		/* market.getMarketPrice(t)      : ステップ t の市場価格 */

		assert this.fundamentalWeight >= 0.0 : "fundamentalWeight >= 0.0";
		assert this.chartWeight >= 0.0 : "chartWeight >= 0.0";
		assert this.noiseWeight >= 0.0 : "noiseWeight >= 0.0";
		
		/* 式 (6) : ファンダメンタル分析項 */
		val fundamentalScale = 1.0 / Math.max(timeWindowSize, 1);
		val fundamentalLogReturn = fundamentalScale * Math.log(market.getFundamentalPrice(t) / market.getMarketPrice(t));
		assert isFinite(fundamentalLogReturn) : "isFinite(fundamentalLogReturn)";

		/* 式 (7) : テクニカル分析項（チャート） */
		val chartScale = 1.0 / Math.max(timeWindowSize, 1);
		val chartMeanLogReturn = noiseScale * Math.log(market.getMarketPrice(t) / market.getMarketPrice(t - timeWindowSize));
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
		val expectedFuturePrice = market.getMarketPrice(t) * Math.exp(expectedLogReturn * timeWindowSize);
		assert isFinite(expectedFuturePrice) : "isFinite(expectedFuturePrice)";


		/* Constant-Absolute Risk-Aversion */
		val recentLogReturns = new ArrayList[Double]();
		for (i in 0..(timeWindowSize - 1)) {
			recentLogReturns.add(Math.log(market.getPrice(t - i) / market.getPrice(t - i - 1)));
		}
		val chartVarianceLogReturn = Statistics.variance(recentLogReturns);
		if (chartVarianceLogReturn <= 1e-32) {
			return orders; // Stop thinking.
		}

		val pi = (x:Double) => Math.log(expectedFuturePrice / x) / (riskAversionConstant * chartVarianceLogReturn * x);
		val fs = (x:Double) => Math.log(expectedFuturePrice) - Math.log(x) - riskAversionConstant * chartVarianceLogReturn * this.getAssetVolume(market) * x;
		val fm = (x:Double) => Math.log(expectedFuturePrice) - Math.log(x) - riskAversionConstant * chartVarianceLogReturn * (this.getAssetVolume(market) * x + this.getCashAmount());

		var priceMaximal:Double;
		var priceOptimal:Double;
		var priceMinimal:Double;
		try {
			priceMaximal = expectedFuturePrice;
			priceOptimal = Brent.optimize(fs, 1e-32, priceMaximal);
			priceMinimal = Brent.optimize(fm, 1e-32, priceMaximal);
		} catch (e:Exception) {
			return orders; // Stop thinking.
		}
		val DEBUG = false;
		if (DEBUG) {
			Console.OUT.println("priceMaximal " + priceMaximal + ", pi() " + pi(priceMaximal));
			Console.OUT.println("priceOptimal " + priceOptimal + ", pi() " + pi(priceOptimal) + ", " + fs(priceOptimal));
			Console.OUT.println("priceMinimal " + priceMinimal + ", pi() " + pi(priceMinimal) + ", " + fm(priceMinimal));
		}
		if (pi(priceMaximal).isNaN() || pi(priceOptimal).isNaN() || pi(priceMinimal).isNaN()) {
			return orders; // Stop thinking.
		}
		assert Math.round(priceMinimal * 1000) <= Math.round(priceOptimal * 1000);
		assert Math.round(priceOptimal * 1000) <= Math.round(priceMaximal * 1000);


		var orderPrice:Double = random.nextDouble() * (priceMaximal - priceMinimal) + priceMinimal;
		var orderVolume:Long = 0;
		assert priceMinimal <= orderPrice;
		assert orderPrice <= priceMaximal;

		if (orderPrice < priceOptimal) {
			orderVolume = (pi(orderPrice) - this.getAssetVolume(market)) as Long;
			if (orderVolume > 0) {
				orders.add(new Order(Order.KIND_BUY_LIMIT_ORDER, this, market, orderPrice, orderVolume, timeWindowSize));
			}
			assert this.getCashAmount() >= orderPrice * orderVolume : ["this.getCashAmount() >= orderPrice * orderVolume", this.getCashAmount(), orderPrice * orderVolume];
		}
		if (orderPrice > priceOptimal) {
			orderVolume = (this.getAssetVolume(market) - pi(orderPrice)) as Long;
			if (orderVolume > 0) {
				orders.add(new Order(Order.KIND_SELL_LIMIT_ORDER, this, market, orderPrice, orderVolume, timeWindowSize));
			}
			assert this.getAssetVolume(market) >= orderVolume : ["this.getAssetVolume(market) >= orderVolume", this.getAssetVolume(market), orderVolume];
		}
		assert orderPrice >= 0.0 : ["orderPrice >= 0.0", orderPrice];
		assert orderVolume >= 0 : ["orderVolume >= 0", orderVolume];

		return orders;
	}

	public static def main(args:Rail[String]) {
//		val riskAversionConstant = 0.207881421039;
//		val expectedFuturePrice = 283.605078562;
//		val varianceLogReturn = 3.84808016118e-07;
//		val assetVolume = 18;
//		val cashAmount = 5191.96178162;
//		val riskAversionConstant = 0.169516948841;
//		val expectedFuturePrice = 299.346192766;
//		val varianceLogReturn = 9.16468822313e-07;
//		val assetVolume = 20;
//		val cashAmount = 603.311911064;
		val riskAversionConstant = 0.488072464385;
		val expectedFuturePrice = 301.275408155;
		val varianceLogReturn = 1.71442629065e-06;
		val assetVolume = 24;
		val cashAmount = 14398.4012076;
		val pi = (x:Double) => Math.log(expectedFuturePrice / x) / (riskAversionConstant * varianceLogReturn * x);
		val fs = (x:Double) => Math.log(expectedFuturePrice) - Math.log(x) - riskAversionConstant * varianceLogReturn * assetVolume * x;
		val fm = (x:Double) => Math.log(expectedFuturePrice) - Math.log(x) - riskAversionConstant * varianceLogReturn * (assetVolume * x + cashAmount);
		
		Console.OUT.println("Optimize priceMaximal " + expectedFuturePrice);
		val priceMaximal = expectedFuturePrice;
		Console.OUT.println("Optimize priceOptimal");
		val priceOptimal = Brent.optimize(fs, 1e-6, priceMaximal);
		Console.OUT.println("Optimize priceMinimal");
		val priceMinimal = Brent.optimize(fm, 1e-6, priceMaximal);
		Console.OUT.println("priceMaximal " + priceMaximal + ", pi() " + pi(priceMaximal));
		Console.OUT.println("priceOptimal " + priceOptimal + ", pi() " + pi(priceOptimal) + ", " + fs(priceOptimal));
		Console.OUT.println("priceMinimal " + priceMinimal + ", pi() " + pi(priceMinimal) + ", " + fm(priceMinimal));
	}
}
