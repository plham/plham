package samples.OptionPortfolio;
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
//import samples.Option.agent.ProspectFCNOptionAgent;
import samples.Option.util.BlackScholes;
import samples.Option.OptionMarket;
import x10.util.Random;
import plham.Env;
import plham.Fundamentals;
import plham.util.Matrix;
import plham.Order;
import samples.Portfolio.FCNBaselMarkowitzPortfolioAgent;
import samples.Portfolio.FCNMarkowitzPortfolioAgent;
import samples.Portfolio.FCNMarkowitzCI2002Main;
import x10.util.Map;
import x10.util.HashMap;
import plham.Main;
import plham.OrderBook;
import cassia.util.random.Gaussian2;
import x10.io.File;
import x10.io.Printer;


public class OptionPortfolioMain extends FCNMarkowitzCI2002Main {

	public static def main(args:Rail[String]) {
		new SequentialRunner(new OptionPortfolioMain()).run(args);
	}




	public def print(sessionName:String) {
	/*	val markets = getMarketsByName("markets");
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
		//dumpExpectedVolatility();*/
		dumpVolatilitySurface();
	}

	public def endprint(sessionName:String, iterationSteps:Long) {
/*		val markets = getMarketsByName("markets");
		val agents = getAgentsByName("agents");		

		for (market in markets) {
			val t = market.getTime();
			var f:File = new File(sessionName +"-"+ market.name+".dat");
			var p:Printer = f.printer();

			val start = t - iterationSteps+1;
			for(var i:Long = start; i<= t; i++){
				p.println(StringUtil.formatArray([
					sessionName,
					i, 
					market.id,
					(market instanceof OptionMarket) ? (market as OptionMarket).getLongName() : market.name,
					market.getPrice(i),
					market.getFundamentalPrice(i),
					"", ""], " ", "", Int.MAX_VALUE));
			}

			p.flush();
			p.close();

		}*/
		//checkZeroSumGame();
		//dumpExpectedVolatility();
		//dumpVolatilitySurface();
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
				/*if (option.isCallOption()) {
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
				}*/
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

	public def beginSimulation(){
		val json = CONFIG;
		this.numStepsOneDay = json("numStepsOneDay").toLong();
		this.numDaysOneMonth = json("numDaysOneMonth").toLong();
		this.TPORT = json("TPORT").toLong();
		this.timeWindowSize = json("timeWindowSize").toLong();
		this.covarfundamentalWeight = json("covarfundamentalWeight").toDouble();
		if(CONFIG.has("fundamentalCorrelations")){
			//Console.OUT.println("# a1");
			if(CONFIG("fundamentalCorrelations").has("logType")){
				//Console.OUT.println("# a2");
				this.logType = CONFIG("fundamentalCorrelations")("logType").toBoolean();
			}else{
					this.logType = true;
			}
		}else{
			this.logType = true;
		}
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

	public def setupMarket(market:Market, json:JSON.Value, random:JSONRandom) {
		market.setTickSize(random.nextRandom(json("tickSize", "-1.0"))); // " tick-size <= 0.0 means no tick size.
		market.setInitialMarketPrice(random.nextRandom(json("marketPrice")));
		market.setInitialFundamentalPrice(random.nextRandom(json("marketPrice")));
		market.setOutstandingShares(random.nextRandom(json("outstandingShares")) as Long);
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

	public def setupAgent(agent:Agent, json:JSON.Value, random:JSONRandom) {
		agent.setCashAmount(random.nextRandom(json("cashAmount")));
		for (market in getMarketsByName(json("markets"))) {
			agent.setMarketAccessible(market);
			agent.setAssetVolume(market, random.nextRandom(json("assetVolume")) as Long);
		}
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
		val agents = new ArrayList[Agent]();
		if (json("class").equals("FCNMarkowitzPortfolioAgent") && !json("class").equals("FCNBaselMarkowitzPortfolioAgent") ) {
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new FCNMarkowitzPortfolioAgent();
				agent.fundamentalWeight = random.nextRandom(json("fundamentalWeight"));
				agent.chartWeight = random.nextRandom(json("chartWeight"));	
				agent.noiseWeight = random.nextRandom(json("noiseWeight"));
				agent.noiseScale = random.nextRandom(json("noiseScale"));
				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
				//val fcRatio = (1.0 + agent.fundamentalWeight) / (1.0 + agent.chartWeight);
				agent.fundamentalMeanReversionTime = random.nextRandom(json("fundamentalMeanReversionTime")) as Long;
				agent.shortSellingAbility = json("shortSellingAbility").toBoolean();
				agent.leverageRate = json("leverageRate").toDouble();
				assert agent.fundamentalWeight >= 0.0 : "fundamentalWeight >= 0.0";
				assert agent.chartWeight >= 0.0 : "chartWeight >= 0.0";
				assert agent.noiseWeight >= 0.0 : "noiseWeight >= 0.0";
				agent.b= random.nextRandom(json("b"));
				agent.TPORT = json("tport").toLong();
				agent.lastUpdated = 0; //正しい？
				//assert json("accessibleMarkets").size() == 2 : "FCNAgents suppose only one Market";
				var markets:ArrayList[Market] = new ArrayList[Market]();
				for (m in 0..(json("accessibleMarkets").size()-1)) {
					val name = json("accessibleMarkets")(m).toString();
					markets.add((GLOBAL(name) as List[Market])(0));
				}
				agent.allMarkets = markets as List[Market];
				agent.accessibleMarkets = markets as List[Market]; 
				for (m in agent.accessibleMarkets) {
					agent.setMarketAccessible(m);
					agent.setAssetVolume(m, random.nextRandom(json("assetVolume")) as Long);
				}
				agent.setCashAmount(random.nextRandom(json("cashAmount")));
				//Console.OUT.println("# a0");
				if(json.has("logType")){
					//Console.OUT.println("# a2");
					agent.logType = json("logType").toBoolean();
				}
				agent.session0iterationDays = CONFIG("simulation")("sessions")(0)("iterationDays").toLong();
				agent.numStepsOneDay  = CONFIG("numStepsOneDay").toLong();
				agent.numDaysOneMonth = CONFIG("numDaysOneMonth").toLong();
				agent.covarfundamentalWeight = CONFIG("covarfundamentalWeight").toDouble();
				agent.orderMarket = agent.marketOrder();
				if (DEBUG == -3) {
					Console.OUT.println("##\tfundamentalWeight:"+ agent.fundamentalWeight );
					Console.OUT.println("##\tchartWeight:"+ agent.chartWeight );
					Console.OUT.println("##\tnoiseWeight:"+ agent.noiseWeight );
					Console.OUT.println("##\tnoiseScale:"+ agent.noiseScale );
					Console.OUT.println("##\ttimeWindowSize:"+ agent.timeWindowSize );
					Console.OUT.println("##\tfundamentalMeanReversionTime:"+ agent.fundamentalMeanReversionTime );
					Console.OUT.println("##\tb:"+ agent.b );
					Console.OUT.println("##\tassetsVolumes:");
					Console.OUT.print("#");
					//FCNBaselMarkowitzCI2002Main.dump(agent.assetsVolumes, agent.orderMarket  );
					Console.OUT.println("##\tcashAmount:"+ agent.cashAmount );
				}

				agents.add(agent);
			}
			//Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}

		if( json("class").equals("FCNBaselMarkowitzPortfolioAgent")){
			val numAgents = json("numAgents").toLong();
			for (i in 0..(numAgents - 1)) {
				val agent = new FCNBaselMarkowitzPortfolioAgent();
				agent.fundamentalWeight = random.nextRandom(json("fundamentalWeight"));
				agent.chartWeight = random.nextRandom(json("chartWeight"));	
				agent.noiseWeight = random.nextRandom(json("noiseWeight"));
				agent.noiseScale = random.nextRandom(json("noiseScale"));
				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
				//val fcRatio = (1.0 + agent.fundamentalWeight) / (1.0 + agent.chartWeight);
				agent.fundamentalMeanReversionTime = random.nextRandom(json("fundamentalMeanReversionTime")) as Long;
				agent.shortSellingAbility = json("shortSellingAbility").toBoolean();
				agent.leverageRate = json("leverageRate").toDouble();
				assert agent.fundamentalWeight >= 0.0 : "fundamentalWeight >= 0.0";
				assert agent.chartWeight >= 0.0 : "chartWeight >= 0.0";
				assert agent.noiseWeight >= 0.0 : "noiseWeight >= 0.0";
				agent.b= random.nextRandom(json("b"));
				agent.TPORT = json("tport").toLong();
				agent.lastUpdated = 0; //正しい？
				//assert json("accessibleMarkets").size() == 2 : "FCNAgents suppose only one Market";
				var markets:ArrayList[Market] = new ArrayList[Market]();
				for (m in 0..(json("accessibleMarkets").size()-1)) {
					val name = json("accessibleMarkets")(m).toString();
					markets.add((GLOBAL(name) as List[Market])(0));
				}
				agent.allMarkets = markets as List[Market];
				agent.accessibleMarkets = markets as List[Market]; 
				for (m in agent.accessibleMarkets) {
					agent.setMarketAccessible(m);
					agent.setAssetVolume(m, random.nextRandom(json("assetVolume")) as Long);
				}
				agent.setCashAmount(random.nextRandom(json("cashAmount")));
				//Console.OUT.println("# a0");
				if(json.has("logType")){
					//Console.OUT.println("# a2");
					agent.logType = json("logType").toBoolean();
				}
				agent.session0iterationDays = CONFIG("simulation")("sessions")(0)("iterationDays").toLong();
				agent.numStepsOneDay  = CONFIG("numStepsOneDay").toLong();
				agent.numDaysOneMonth = CONFIG("numDaysOneMonth").toLong();
				agent.covarfundamentalWeight = CONFIG("covarfundamentalWeight").toDouble();
				agent.orderMarket = agent.marketOrder();

				agent.distanceType = json("distanceType").toString();
				agent.riskType = json("riskType").toString();
				agent.confInterval = json("confInterval").toDouble();	//VaR,ES計算時に用いる信頼水準のパーセンテージx( x ∈ (0.0, 1.0) )  nomura2014,pdfによれば，VaRのときは0.99でESのときは0.975.
				agent.confCoEfficient = Gaussian2.confidence(agent.confInterval); //信頼係数
				//ただバーゼル2.5だとストレスVaRとか入れてたりするので，更にややこしくて美しくない.
				agent.numDaysVaR = json("numDaysVaR").toLong();
				agent.sizeDistVaR = json("sizeDistVaR").toLong();	//VaR,ESの計算をするときのリターンのサンプル（毎日のリターン）の数(サンプルはTPORT毎の過去の時系列リターン)．
				agent.coMarketRisk = json("coMarketRisk").toDouble();	//ウェブで見つけたデロイトトーマツの資料によれば，12.5となっていた．
				agent.threshold = json("threshold").toDouble();	//バーゼル規制違反の有無判断に用いる自己資本比率の閾値x( x ∈ (0.0, 1.0) ) 国際統一基準は0.08、国内基準は0.04
				agent.isLimitVariable = json("isLimitVariable").toBoolean(); //If IsLimitVariable is true, we use limitOrderPriceRate. Otherwise, we use limitOrderPrice.
				if(agent.isLimitVariable){
					agent.underLimitPriceRate = json("underLimitPriceRate").toDouble();
					agent.overLimitPriceRate = json("overLimitPriceRate").toDouble();
				}else{
					agent.underLimitPrice = json("underLimitPrice").toDouble();
					agent.overLimitPrice = json("overLimitPrice").toDouble();
				}

				if (DEBUG == -3) {
					Console.OUT.println("##\tfundamentalWeight:"+ agent.fundamentalWeight );
					Console.OUT.println("##\tchartWeight:"+ agent.chartWeight );
					Console.OUT.println("##\tnoiseWeight:"+ agent.noiseWeight );
					Console.OUT.println("##\tnoiseScale:"+ agent.noiseScale );
					Console.OUT.println("##\ttimeWindowSize:"+ agent.timeWindowSize );
					Console.OUT.println("##\tfundamentalMeanReversionTime:"+ agent.fundamentalMeanReversionTime );
					Console.OUT.println("##\tb:"+ agent.b );
					Console.OUT.println("##\tassetsVolumes:");
					Console.OUT.print("#");
					//this.dump(agent.assetsVolumes, agent.orderMarket  );
					Console.OUT.println("##\tcashAmount:"+ agent.cashAmount );
				}


				agents.add(agent);
			}
			//Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
		}

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
//		if (json("class").equals("StraddleOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new StraddleOptionAgent();
//				setupAgent(agent, json, random);
//				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}
//		if (json("class").equals("StrangleOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new StrangleOptionAgent();
//				setupAgent(agent, json, random);
//				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}
//		if (json("class").equals("SyntheticOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new SyntheticOptionAgent();
//				setupAgent(agent, json, random);
//				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}
//		if (json("class").equals("PutCallParityOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new PutCallParityOptionAgent();
//				setupAgent(agent, json, random);
//				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
//				agent.numSamples = random.nextRandom(json("numSamples")) as Long;
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}
//		if (json("class").equals("DeltaHedgeOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new DeltaHedgeOptionAgent();
//				setupAgent(agent, json, random);
//				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
//				agent.hedgeBaselineVolume = random.nextRandom(json("hedgeBaselineVolume")) as Long;
//				agent.hedgeDeltaThreshold = random.nextRandom(json("hedgeDeltaThreshold")) as Long;
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}
//		if (json("class").equals("ExCoverDashOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new ExCoverDashOptionAgent();
//				setupAgent(agent, json, random);
//				agent.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
//				agent.hedgeBaselineVolume = random.nextRandom(json("hedgeBaselineVolume")) as Long;
//				agent.hedgeDeltaThreshold = random.nextRandom(json("hedgeDeltaThreshold")) as Long;
//				agent.stepSize = random.nextRandom(json("stepSize")) as Long;
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}
//		if (json("class").equals("LeverageFCNOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new LeverageFCNOptionAgent();
//				setupFCNOptionAgent(agent, json, random);
//				agent.isUtilityMax = json("isUtilityMax").toBoolean();
//				agent.leverageBuyRate = random.nextRandom(json("leverageBuyRate"));
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}
//		if (json("class").equals("ProspectFCNOptionAgent")) {
//			val numAgents = json("numAgents").toLong();
//			for (i in 0..(numAgents - 1)) {
//				val agent = new ProspectFCNOptionAgent();
//				setupFCNOptionAgent(agent, json, random);
//				agent.probabilityWeight = random.nextRandom(json("probabilityWeight", "0.91"));
//				agent.riskSensitivity = random.nextRandom(json("riskSensitivity", "0.00055"));
//				agent.lossAversion = random.nextRandom(json("lossAversion", "2.3"));
//				agent.lossProbability = random.nextRandom(json("lossProbability", "0.5"));
//				agents.add(agent);
//			}
//			Console.OUT.println("# " + json("class").toString() + " : " + JSON.dump(json));
//		}

		return agents;
	}

	//今期の時間TimeとtimeSizeを基に，TPORT日毎のリターンをtimeSize個獲得する
	public def recentMarketPortfolioReturnsTPORT(t:Long, timeSize:Long, position:HashMap[Market,Double], markets:List[Market]):ArrayList[Double]{
		return recentMarketPortfolioReturnsSomeDays(t, this.TPORT, timeSize, position, markets);
	}

	//今期の時間TimeとtimeSizeを基に、月次リターンをtimeSize個獲得する.
	public def recentMarketPortfolioReturnsOneMonth(t:Long, timeSize:Long, position:HashMap[Market,Double], markets:List[Market]):ArrayList[Double]{
		return recentMarketPortfolioReturnsSomeDays(t, this.numDaysOneMonth, timeSize, position, markets);
	}

	//今期の時間TimeとtimeSizeを基に、日次リターンをtimeSize個獲得する.
	public def recentMarketPortfolioReturnsOneDay(t:Long, timeSize:Long, position:HashMap[Market,Double], markets:List[Market]):ArrayList[Double]{
		return recentMarketPortfolioReturnsSomeDays(t, 1, timeSize, position, markets);
	}


	//今期の時間TimeとSomeDays,timeSizeを基に、SomeDays日毎のリターンをtimeSize個獲得する.
	public def recentMarketPortfolioReturnsSomeDays(t:Long, SomeDays:Long, timeSize:Long, position:HashMap[Market,Double], markets:List[Market]):ArrayList[Double]{
		val T = t - t%(SomeDays*this.numStepsOneDay);
		var out:ArrayList[Double] = new ArrayList[Double]();
		for(var i:Long = 0; i < timeSize; i++){
			var r:Double;
			if(this.logType){
				r = Math.log(
						presentMarketPortfolioPriceSomeDays( T +(i+1-timeSize)*SomeDays*this.numStepsOneDay ,SomeDays, position, markets)
							/ presentMarketPortfolioPriceSomeDays( T +(i-timeSize)*SomeDays*this.numStepsOneDay ,SomeDays, position, markets)
					);
			}else{
				r = ( presentMarketPortfolioPriceSomeDays( T +(i+1-timeSize)*SomeDays*this.numStepsOneDay ,SomeDays, position, markets)
					- presentMarketPortfolioPriceSomeDays( T +(i-timeSize)*SomeDays*this.numStepsOneDay ,SomeDays, position, markets)
				)/presentMarketPortfolioPriceSomeDays( T +(i-timeSize)*SomeDays*this.numStepsOneDay ,SomeDays, position, markets);
			}
			out.add(r);
		}
		return out;
	}


	//TPORTはじめの時点でのポジションの市場価値を与える.
	public def presentMarketPortfolioPriceTPORT(t:Long, position:HashMap[Market,Double], markets:List[Market]): Double {
		return presentMarketPortfolioPriceSomeDays(t,this.TPORT, position, markets);
	}

	//月はじめの時点でのポジションの市場価値を与える.
	public def presentMarketPortfolioPriceOneMonth(t:Long, position:HashMap[Market,Double], markets:List[Market]): Double {
		return presentMarketPortfolioPriceSomeDays(t,this.numDaysOneMonth, position, markets);
	}


	//その日のはじめの時点でのポジションの市場価値を与える.
	public def presentMarketPortfolioPriceOneDay(t:Long, position:HashMap[Market,Double], markets:List[Market]): Double {
		return presentMarketPortfolioPriceSomeDays(t,1, position, markets);
	}


	//今期の時間TimeとSomeDaysを基に、SomeDays開始時点でのポジションの市場価値を与える. 
	public def presentMarketPortfolioPriceSomeDays(t:Long,SomeDays:Long, position:HashMap[Market,Double], markets:List[Market]): Double {
		val T = t - t%(SomeDays*this.numStepsOneDay);
		var out:Double = 0.0;
		for(market in markets){
			out = out + market.getMarketPrice(T)*position.get(market);
		}
		return out;
	}

	public def presentMarketPortfolioPriceStep(t:Long, position:HashMap[Market,Double], markets:List[Market]): Double {
		val T = t;
		var out:Double = 0.0;
		for(market in markets){
			out = out + market.getMarketPrice(T)*position.get(market);
		}
		return out;
	}

}


