package samples.Option;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.StringUtil;
import plham.Agent;
import plham.Market;
import plham.util.JSON;
import plham.util.JSONRandom;
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

public class OptionMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new OptionMain()).run(args);
	}

	public def print(sessionName:String) {
		val markets = getMarketsByName("markets");
		val agents = getAgentsByName("agents");
		for (market in markets) {
			val t = market.getTime();
			Console.OUT.println(StringUtil.formatArray([
				sessionName,
				t, 
				market.id,
				(market instanceof OptionMarket) ? (market as OptionMarket).getLongName() : market.name,
				market.getPrice(t),
				market.getFundamentalPrice(t),
				"", ""], " ", "", Int.MAX_VALUE));
		}
		//checkZeroSumGame();
		//dumpExpectedVolatility();
		dumpVolatilitySurface();
	}

	public def dumpVolatilitySurface() {
		val markets = getMarketsByName("markets");
		for (market in markets) {
			if (market instanceof OptionMarket) {
				val t = market.getTime();
				val option = market as OptionMarket;
				val underlying = option.getUnderlyingMarket();
				val premium = option.getPrice();
				val underlyingPrice = underlying.getPrice();
				val strikePrice = option.getStrikePrice();
				val maturityTime = option.getMaturityInterval();
				val volatilityGuess = 1.0; // Just an initial guess, the solution is unique
				val timeToMaturity = option.getTimeToMaturity();
				val rateToMaturity = timeToMaturity / (option.getMaturityInterval() + 0.0);
				val riskFreeRate = 0.001;
				val dividendYield = 0.0;
				var impliedVolCall:Double = 0.0;
				var impliedVolPut:Double = 0.0;
				if (option.isCallOption()) {
					Console.OUT.println("#BlackScholes(Call): premium=" + premium
						+ ", underlyingPrice=" + underlyingPrice
						+ ", strikePrice=" + strikePrice
						+ ", volatilityGuess=" + volatilityGuess
						+ ", rateToMaturity=" + rateToMaturity
						+ ", riskFreeRate=" + riskFreeRate
						+ ", dividendYield=" + dividendYield);
					impliedVolCall = BlackScholes.impliedVolatilityCall(premium, underlyingPrice, strikePrice, volatilityGuess, rateToMaturity, riskFreeRate, dividendYield);
				}
				if (option.isPutOption()) {
					Console.OUT.println("#BlackScholes(Put): premium=" + premium
						+ ", underlyingPrice=" + underlyingPrice
						+ ", strikePrice=" + strikePrice
						+ ", volatilityGuess=" + volatilityGuess
						+ ", rateToMaturity=" + rateToMaturity
						+ ", riskFreeRate=" + riskFreeRate
						+ ", dividendYield=" + dividendYield);
					impliedVolPut = BlackScholes.impliedVolatilityPut(premium, underlyingPrice, strikePrice, volatilityGuess, rateToMaturity, riskFreeRate, dividendYield);
				}
				Console.OUT.println(StringUtil.formatArray([
					"#IMPLIED_VOLATILITY",
					t, 
					option.id,
					option.getLongName(),
					underlying.id,
					option.getPrice(), /* Premium */
					underlying.getPrice(),
					strikePrice,    /* This must be used to show the surface */
					maturityTime,
					timeToMaturity, /* This must be used to show the surface */
					impliedVolCall,
					impliedVolPut,
					"", ""], " ", "", Int.MAX_VALUE));
			}
		}
	}

	public def dumpExpectedVolatility() {
		val markets = getMarketsByName("markets");
		val agents = getAgentsByName("agents");
		for (agent in agents) {
			if (agent instanceof FCNOptionAgent) {
				val a = agent as FCNOptionAgent;
				val option = a.chooseOptionMarket(markets);
				val underlying = option.getUnderlyingMarket();
				val expectedVolatility = a.computeExpectedVolatility(underlying);
				Console.OUT.println(StringUtil.formatArray([
					"#EXP-VOL",
					option.getTime(), 
					a.id,
					option.id,
					underlying.id,
					expectedVolatility,
					"", ""], " ", "", Int.MAX_VALUE));
			}
		}
	}

	public def checkZeroSumGame() {
		val markets = getMarketsByName("markets");
		val agents = getAgentsByName("agents");

		var cashAmount:Double = 0.0;
		var cashAmountAbs:Double = 0.0;
		val assetVolumes = new Rail[Long](markets.size());
		val assetVolumesAbs = new Rail[Long](markets.size());
		for (agent in agents) {
			cashAmount += agent.getCashAmount();
			cashAmountAbs += Math.abs(agent.getCashAmount());
			for (market in markets) {
				if (agent.isMarketAccessible(market)) {
					assetVolumes(market.id) += agent.getAssetVolume(market);
					assetVolumesAbs(market.id) += Math.abs(agent.getAssetVolume(market));
				}
			}
		}
		Console.OUT.print("#ZEROSUM");
		Console.OUT.print(" " + cashAmount);
		for (market in markets) {
			Console.OUT.print(" " + assetVolumes(market.id));
		}
		Console.OUT.print(" " + cashAmountAbs);
		for (market in markets) {
			Console.OUT.print(" " + assetVolumesAbs(market.id));
		}
		Console.OUT.println();
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
					markets.add(market);

					Console.OUT.println("# " + json("class").toString() + "" + [kindName, underlying.id, (strikePrice as Long), maturityTime] + " : " + JSON.dump(json));
				}
			}
		}
		return markets;
	}

	public def setupFCNOptionAgent(agent:FCNOptionAgent, json:JSON.Value, random:JSONRandom) {
		setupAgent(agent, json, random);

		agent.fundamentalWeight = random.nextRandom(json("fundamentalWeight"));
		agent.chartWeight = random.nextRandom(json("chartWeight"));
		agent.noiseWeight = random.nextRandom(json("noiseWeight"));
		agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
		agent.numSamples = random.nextRandom(json("numSamples")) as Long;
		agent.alpha = random.nextRandom(json("alpha"));
		agent.betaPos = random.nextRandom(json("betaPos"));
		agent.betaNeg = random.nextRandom(json("betaNeg"));
		agent.sigma = random.nextRandom(json("sigma"));
	}

	public def createAgents(json:JSON.Value):List[Agent] {
		val random = new JSONRandom(getRandom());
		val agents = super.createAgents(json);
		if (json("class").equals("FCNOptionAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new FCNOptionAgent();
				setupFCNOptionAgent(agent, json, random);
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
//		if (json("class").equals("FundamentalistOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new FundamentalistOptionAgent();
//				agent.alpha = random.nextRandom(json("alpha"));
//				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
//				for (market in getMarketsByName(json("markets"))) {
//					agent.setMarketAccessible(market);
//				}
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}
//		if (json("class").equals("ChartistOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new ChartistOptionAgent();
//				agent.betaPos = random.nextRandom(json("betaPos"));
//				agent.betaNeg = random.nextRandom(json("betaNeg"));
//				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
//				agent.numSamples = random.nextRandom(json("numSamples")) as Long;
//				for (market in getMarketsByName(json("markets"))) {
//					agent.setMarketAccessible(market);
//				}
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}
//		if (json("class").equals("NoiseOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new NoiseOptionAgent();
//				agent.sigma = random.nextRandom(json("sigma"));
//				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
//				for (market in getMarketsByName(json("markets"))) {
//					agent.setMarketAccessible(market);
//				}
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}
		if (json("class").equals("StraddleOptionAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new StraddleOptionAgent();
				setupAgent(agent, json, random);
				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		if (json("class").equals("StrangleOptionAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new StrangleOptionAgent();
				setupAgent(agent, json, random);
				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		if (json("class").equals("SyntheticOptionAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new SyntheticOptionAgent();
				setupAgent(agent, json, random);
				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		if (json("class").equals("PutCallParityOptionAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new PutCallParityOptionAgent();
				setupAgent(agent, json, random);
				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
				agent.numSamples = random.nextRandom(json("numSamples")) as Long;
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		if (json("class").equals("DeltaHedgeOptionAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new DeltaHedgeOptionAgent();
				setupAgent(agent, json, random);
				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
				agent.hedgeBaselineVolume = random.nextRandom(json("hedgeBaselineVolume")) as Long;
				agent.hedgeDeltaThreshold = random.nextRandom(json("hedgeDeltaThreshold")) as Long;
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		if (json("class").equals("ExCoverDashOptionAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new ExCoverDashOptionAgent();
				setupAgent(agent, json, random);
				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
				agent.hedgeBaselineVolume = random.nextRandom(json("hedgeBaselineVolume")) as Long;
				agent.hedgeDeltaThreshold = random.nextRandom(json("hedgeDeltaThreshold")) as Long;
				agent.stepSize = random.nextRandom(json("stepSize")) as Long;
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		if (json("class").equals("LeverageFCNOptionAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new LeverageFCNOptionAgent();
				setupFCNOptionAgent(agent, json, random);
				agent.isUtilityMax = json("isUtilityMax").toBoolean();
				agent.leverageBuyRate = random.nextRandom(json("leverageBuyRate"));
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		if (json("class").equals("ProspectFCNOptionAgent")) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new ProspectFCNOptionAgent();
				setupFCNOptionAgent(agent, json, random);
				agent.probabilityWeight = random.nextRandom(json("probabilityWeight", "0.91"));
				agent.riskSensitivity = random.nextRandom(json("riskSensitivity", "0.00055"));
				agent.lossAversion = random.nextRandom(json("lossAversion", "2.3"));
				agent.lossProbability = random.nextRandom(json("lossProbability", "0.5"));
				agents.add(agent);
			}
			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}
		return agents;
	}


	public def setupOptionMarket(market:OptionMarket, json:JSON.Value, random:JSONRandom) {
		setupMarket(market, json, random);
		market.kind = json("kind").equals("Call") ? OptionMarket.KIND_CALL_OPTION : OptionMarket.KIND_PUT_OPTION;
		market.setUnderlyingMarket(getMarketByName(json("markets")));
		market.setStrikePrice(json("strikePrice").toDouble());
		market.setMaturityInterval(json("maturity").toLong());
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
}
