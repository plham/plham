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
		val sim = new OptionMain();
		FCNOptionAgent.register(sim);
		StraddleOptionAgent.register(sim);
		StrangleOptionAgent.register(sim);
		SyntheticOptionAgent.register(sim);
		PutCallParityOptionAgent.register(sim);
		DeltaHedgeOptionAgent.register(sim);
		ExCoverDashOptionAgent.register(sim);
		LeverageFCNOptionAgent.register(sim);
		ProspectFCNOptionAgent.register(sim);
		OptionMarket.register(sim);
		OptionMarketCluster.register(sim);
		new SequentialRunner(sim).run(args);
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
				market.name,
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
					option.name,
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
}

