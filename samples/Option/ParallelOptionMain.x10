package samples.Option;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Market;
import plham.util.JSON;
import plham.util.JSONRandom;
import plham.main.ParallelRunnerProto;
import plham.main.SequentialRunner;
import samples.CI2002.CI2002Main;
import samples.Option.agent.FCNOptionAgent;
//import samples.Option.agent.AbstractFCNOptionAgent;
//import samples.Option.agent.FundamentalistOptionAgent;
//import samples.Option.agent.ChartistOptionAgent;
//import samples.Option.agent.NoiseOptionAgent;
import samples.Option.agent.StraddleOptionAgent;
import samples.Option.agent.StrangleOptionAgent;
import samples.Option.agent.SyntheticOptionAgent;
import samples.Option.agent.PutCallParityOptionAgent;
import samples.Option.agent.DeltaHedgeOptionAgent;
import samples.Option.agent.ExCoverDashOptionAgent;
import samples.Option.agent.LeverageFCNOptionAgent;
import samples.Option.agent.ProspectFCNOptionAgent;
import samples.Option.util.BlackScholes;

public class ParallelOptionMain extends OptionMain {

	public static def main(args:Rail[String]) {
		new ParallelRunnerProto[ParallelOptionMain](() => new ParallelOptionMain()).run(args);
	}

	public def createMarkets(json:JSON.Value):List[Market] {
		val random = new JSONRandom(getRandom());
		val markets = super.createMarkets(json);
		if (json("class").equals("OptionMarket")) {
			val market = new OptionMarket();
			setupOptionMarket(market, json, random);
			markets.add(market);

			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		if (json("class").equals("OptionMarketCluster")) {
			markets.addAll(createOptionMarkets(json, random));
		}
		return markets;
	}

	public def createOptionMarkets(json:JSON.Value, random:JSONRandom) {
		val underlying = getMarketByName(json("markets")(0));
		var list:JSON.Value;

		val strikePrices = new ArrayList[Double]();
		list = json("strikePrices");
		for (i in 0..(list.size() - 1)) {
			val strikePrice = list(i).toDouble();
			strikePrices.add(strikePrice);
		}
		strikePrices.sort();

		val maturityTimes = new ArrayList[Long]();
		list = json("maturityTimes");
		for (i in 0..(list.size() - 1)) {
			val maturityTime = list(i).toLong();
			maturityTimes.add(maturityTime);
		}
		maturityTimes.sort();

		val markets = new ArrayList[Market]();

		for (strikePrice in strikePrices) {
			for (maturityTime in maturityTimes) {
				for (k in 0..1) { // Call and Put pairs
					val kindName = (k == 0) ? "Call" : "Put";
					val market = new OptionMarket();
					//setupMarket(market, json, random);
					market.setTickSize(random.nextRandom(json("tickSize", "-1.0"))); // " tick-size <= 0.0 means no tick size.
					market.setInitialMarketPrice(random.nextRandom(json("marketPrice")));
					market.setInitialFundamentalPrice(random.nextRandom(json("marketPrice", "fundamentalPrice")));
					market.setOutstandingShares(random.nextRandom(json("outstandingShares")) as Long);
					market.kind = kindName.equals("Call") ? OptionMarket.KIND_CALL_OPTION : OptionMarket.KIND_PUT_OPTION;
					market.setUnderlyingMarket(underlying);
					market.setStrikePrice(strikePrice);
					market.setMaturityInterval(maturityTime);
					market.env = this;
					markets.add(market);
					Console.OUT.println("# " + json("class").toString() + "" + [kindName, underlying.id, (strikePrice as Long), maturityTime] + " : " + JSON.dump(json));
				}
			}
		}
		return markets;
	}

}
