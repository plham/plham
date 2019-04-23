package samples.Portfolio;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;
import x10.util.StringUtil;
import plham.Agent;
import plham.Env;
import plham.Fundamentals;
import plham.util.Matrix;
import plham.Market;
import plham.Order;
import samples.Portfolio.FCNMarkowitzPortfolioAgent;
import cassia.util.JSON;
import x10.util.Map;
import x10.util.HashMap;
import plham.main.SequentialRunner;
import plham.Main;
import plham.util.JSONRandom;
import plham.OrderBook;
import samples.Portfolio.PortfolioMarket;

public class FCNMarkowitzCI2002Main extends Main {
	public var numStepsOneDay:Long;
	public var numDaysOneMonth:Long;
	public var TPORT:Long;
	public var timeWindowSize:Long;
	public var covarfundamentalWeight:Double;
	public var logType:boolean;
	public var DEBUG:Long=0;

	public static def main(args:Rail[String]) {
		val sim = new FCNMarkowitzCI2002Main();
		FCNMarkowitzPortfolioAgent.register(sim);
		PortfolioMarket.register(sim);
		new SequentialRunner(sim).run(args);
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

	public def print(sessionName:String) { 
		val markets = getMarketsByName("markets");
		val agents = getAgentsByName("agents");

		var trueT:Long = getTime(markets);

		if(trueT>=1){
			trueT = trueT -1;
		}
		var TS:Rail[Long] = getTimeStructure(trueT);

		val days = TS(0)*this.numDaysOneMonth + TS(1);

/*		if (DEBUG == -4) {

			if(TS(2)==0){
				if(TS(1)==0){
					Console.OUT.println("#MonthStructure:");
					Console.OUT.print("#");
					Matrix.dump(TS);
				}
	
				Console.OUT.println("##dayStructure:");
				Console.OUT.print("##");
				Matrix.dump(TS);
				Console.OUT.println("#(days="+days+")");
				//Console.OUT.println("##=========");
			}

			if(TS(0)>=1 && TS(2)==0 /*&& TS(1)==0*//* ){
				val timeSize = Math.min(TS(0),this.timeWindowSize);
				val returnMonth:HashMap[Market,ArrayList[Double]] = recentMarketLogReturnsOneMonth(trueT,timeSize,markets);
				val returnMonth2:HashMap[Market,ArrayList[Double]] = recentFundamentalLogReturnsOneMonth(trueT,timeSize,markets);
				for (market in markets) {
					val RM = returnMonth.get(market);
					Console.OUT.print("#"+market.name+"MonthReturns:");
					for(R in RM){
						Console.OUT.print(R+",");
					}
					Console.OUT.println("");
				}
				if(timeSize == this.timeWindowSize){
					for (market in markets) {
						Console.OUT.print("#monthexpected"+market.name+":"+ expectedLogReturnOneMonth(trueT, timeSize, markets).get(market) +"\t" + expectedRisk(returnMonth, returnMonth2 , markets).get(market).get(market) );
					}
					Console.OUT.println("");
				}
			}

			if(TS(1)>=1 && TS(2)==0 ){
				val timeSize = Math.min(days,this.timeWindowSize);
				val returnDay:HashMap[Market,ArrayList[Double]] = recentMarketLogReturnsOneDay(trueT, timeSize, markets);
				val returnDay2:HashMap[Market,ArrayList[Double]] = recentFundamentalLogReturnsOneDay(trueT, timeSize, markets);
				for (market in markets) {
					val RD = returnDay.get(market);
					Console.OUT.print("#"+market.name+"DayReturns:");
					for(R in RD){
						Console.OUT.print(R+",");
					}
					Console.OUT.println("");
				}
				if(timeSize == this.timeWindowSize){
					for (market in markets) {
						Console.OUT.print("#dayexpected"+market.name+":"+ expectedLogReturnOneDay(trueT, timeSize, markets).get(market) +"\t" + expectedRisk(returnDay, returnDay2 , markets).get(market).get(market) );
					}
					Console.OUT.println("");
				}
			}
		}*/	

		for (market in markets) {
			val t = market.getTime();
			Console.OUT.println(StringUtil.formatArray([
				sessionName,
				t, 
				market.id,
				market.name,
				//(market.isRunning() ? 1 : 0),
				market.getMarketPrice(t),
				market.getFundamentalPrice(t),
				//market.executedOrdersCounts(t),
				//market.getBuyOrderBook().size(),
				//market.getSellOrderBook().size(),
				market.getBuyOrderBook().getBestPrice(),
				market.getSellOrderBook().getBestPrice(),
				getOrderBookVolumes(market.getBuyOrderBook()),
				getOrderBookVolumes(market.getSellOrderBook()),
				"",""], " ", "", Int.MAX_VALUE));
		}
	}


	public def getOrderBookVolumes(ob:OrderBook):Long{
		var out:Long = 0;
		val n = ob.size();
		if(n != 0){
			val q = ob.queue;
			for(order in q){
				out = out + order.volume;
			}
			return out;
		}else{
			return out;
		}
	}

	//11. TPORT期毎のnowTime - timeSize*TPORT*numStepsOneDay期からnowTime期までの各市場の市場とファンダメンタルのリターンを元に、
	//リスク（分散共分散行列）を計算し、その荷重和を返す。 
	public def expectedRisk(recentMarketReturnsTPORT:HashMap[Market,ArrayList[Double]], recentFundamentalReturnsTPORT:HashMap[Market,ArrayList[Double]], markets:List[Market] ):HashMap[Market,HashMap[Market,Double]]{
		var out1:HashMap[Market,HashMap[Market,Double]] = new HashMap[Market,HashMap[Market,Double]]();
		var out2:HashMap[Market,HashMap[Market,Double]] = new HashMap[Market,HashMap[Market,Double]]();
		var trueout:HashMap[Market,HashMap[Market,Double]] = new HashMap[Market,HashMap[Market,Double]]();

		//リターンの平均を計算
		var aves:Map[Market,Double] = new HashMap[Market,Double]();
		var faves:Map[Market,Double] = new HashMap[Market,Double]();
		for(i in 0..(markets.size() - 1)){
			var ave:Double =0;
			var fave:Double =0;
			val recentMarketReturns = recentMarketReturnsTPORT.get(markets(i));
			val recentFundamentalReturns = recentFundamentalReturnsTPORT.get(markets(i));
	   		for(var j:Long = 0; j < recentMarketReturns.size(); ++j){
				ave = ave + recentMarketReturns(j);
				fave = fave +  recentFundamentalReturns(j);
			}
			ave = ave/(recentMarketReturns.size() as Double );
			fave = fave/(recentFundamentalReturns.size() as Double );
			aves.put(markets(i), ave);
			faves.put(markets(i), fave);
		}
		//分散共分散を計算しoutに格納.
		for(i in 0..(markets.size() - 1)){
			var med:HashMap[Market,Double] = new HashMap[Market,Double](); 
			var fmed:HashMap[Market,Double] = new HashMap[Market,Double](); 
			var tmed:HashMap[Market,Double] = new HashMap[Market,Double](); 
			for(j in 0..(markets.size() - 1)){
				val recentMarketReturns1 = recentMarketReturnsTPORT.get(markets(i));
				val recentMarketReturns2 = recentMarketReturnsTPORT.get(markets(j));

				val recentFundamentalReturns1 = recentFundamentalReturnsTPORT.get(markets(i));
				val recentFundamentalReturns2 = recentFundamentalReturnsTPORT.get(markets(j));

				assert recentMarketReturns1.size() == recentMarketReturns2.size()  : "sizeError";
				assert recentFundamentalReturns1.size() == recentFundamentalReturns2.size()  : "sizeError";
				assert recentMarketReturns1.size() == recentFundamentalReturns1.size()  : "sizeError";
				var risk:Double = 0;
				var frisk:Double = 0;
				var tRisk:Double = 0;
 				for(var k:Long = 0; k < recentMarketReturns1.size(); ++k){
					risk = risk + (aves.get(markets(i)) - recentMarketReturns1(k) )* (aves.get(markets(j)) - recentMarketReturns2(k) );
					frisk = frisk + (faves.get(markets(i)) - recentFundamentalReturns1(k) )* (faves.get(markets(j)) - recentFundamentalReturns2(k) );
				}
				risk = risk/(recentMarketReturns1.size()-1);
				frisk = frisk/(recentFundamentalReturns1.size()-1);
				tRisk = covarfundamentalWeight*risk + (1-covarfundamentalWeight)*tRisk;
				med.put(markets(j),risk);
				fmed.put(markets(j),risk);
				tmed.put(markets(j),tRisk);
			}
			out1.put(markets(i),med);
			out2.put(markets(i),med);
			trueout.put(markets(i),tmed);
		}
		return trueout;
	}


	//今期の時間TとtimeSizeを基に、TPORT日毎のtimeSize個の各市場の市場価格の変化率サンプルから計算されたlogリターンを計算する。  
	public def expectedNormalReturnTPORT(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,Double]{
		return expectedNormalReturnSomeDays(Time, this.TPORT, timeSize, markets);
	}

	//今期の時間TとtimeSizeを基に、月次のtimeSize個の各市場の市場価格の変化率サンプルから計算されたlogリターンを計算する。  
	public def expectedNormalReturnOneMonth(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,Double]{
		return expectedNormalReturnSomeDays(Time, this.numDaysOneMonth, timeSize, markets);
	}

	//今期の時間TとtimeSizeを基に、日次のtimeSize個の各市場の市場価格の変化率サンプルから計算されたlogリターンを計算する。  
	public def expectedNormalReturnOneDay(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,Double]{
		return expectedNormalReturnSomeDays(Time, 1, timeSize, markets);
	}

	//今期の時間TとSomeDays,timeSizeを基に、SomeDays日毎のtimeSize個の各市場の市場価格の変化率サンプルから計算されたlogリターンを計算する。 
	public def expectedNormalReturnSomeDays(Time:Long,SomeDays:Long, timeSize:Long, markets:List[Market]):HashMap[Market,Double]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		val recentMarketNormalReturns:HashMap[Market,ArrayList[Double]] = recentMarketNormalReturnsSomeDays(T, SomeDays, timeSize, markets);
		//リターンの平均を計算
		var aves:HashMap[Market,Double] = new HashMap[Market,Double]();
		for(market in markets){
			var ave:Double =0;
			val normalReturns = recentMarketNormalReturns.get(market);
	   		for(var i:Long = 0; i < normalReturns.size(); ++i){
				ave = ave + normalReturns(i);
			}
			ave = ave/(normalReturns.size() as Double );
			aves.put(market, ave);
		}
		return aves;
	}



	//今期の時間TとtimeSizeを基に、TPORT日毎のtimeSize個の各市場の市場価格の変化率サンプルから計算されたlogリターンを計算する。  
	public def expectedLogReturnTPORT(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,Double]{
		return expectedLogReturnSomeDays(Time, this.TPORT, timeSize, markets);
	}

	//今期の時間TとtimeSizeを基に、月次のtimeSize個の各市場の市場価格の変化率サンプルから計算されたlogリターンを計算する。  
	public def expectedLogReturnOneMonth(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,Double]{
		return expectedLogReturnSomeDays(Time, this.numDaysOneMonth, timeSize, markets);
	}

	//今期の時間TとtimeSizeを基に、日次のtimeSize個の各市場の市場価格の変化率サンプルから計算されたlogリターンを計算する。  
	public def expectedLogReturnOneDay(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,Double]{
		return expectedLogReturnSomeDays(Time, 1, timeSize, markets);
	}

	//今期の時間TとSomeDays,timeSizeを基に、SomeDays日毎のtimeSize個の各市場の市場価格の変化率サンプルから計算されたlogリターンを計算する。 
	public def expectedLogReturnSomeDays(Time:Long,SomeDays:Long, timeSize:Long, markets:List[Market]):HashMap[Market,Double]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		val recentMarketLogReturns:HashMap[Market,ArrayList[Double]] = recentMarketLogReturnsSomeDays(T, SomeDays, timeSize, markets);
		//リターンの平均を計算
		var aves:HashMap[Market,Double] = new HashMap[Market,Double]();
		for(market in markets){
			var ave:Double =0;
			val logReturns = recentMarketLogReturns.get(market);
	   		for(var i:Long = 0; i < logReturns.size(); ++i){
				ave = ave + logReturns(i);
			}
			ave = ave/(logReturns.size() as Double );
			aves.put(market, ave);
		}
		return aves;
	}


	//今期の時間TimeとtimeSizeを基に、TPORT日毎のtimeSize個の各市場の理論価格の変化率を獲得する。 
	public def recentFundamentalNormalReturnsTPORT(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalLogReturnsSomeDays(Time, this.TPORT, timeSize, markets);
	}

	//今期の時間TimeとtimeSizeを基に、月次のtimeSize個の各市場の理論価格の変化率を獲得する。 
	public def recentFundamentalNormalReturnsOneMonth(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalNormalReturnsSomeDays(Time, this.numDaysOneMonth, timeSize, markets);
	}

	//今期の時間TimeとtimeSizeを基に、日次のtimeSize個の各市場の理論価格の変化率を獲得する。 
	public def recentFundamentalNormalReturnsOneDay(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalNormalReturnsSomeDays(Time, 1, timeSize, markets);
	}

	//今期の時間TimeとSomeDays,timeSizeを基に、SomeDays日毎のtimeSize個の各市場の理論価格の変化率を獲得する。 
	public def recentFundamentalNormalReturnsSomeDays(Time:Long,SomeDays:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		var recents:HashMap[Market,ArrayList[Double]] = new HashMap[Market,ArrayList[Double]](0);
		for(i in 0..(markets.size() - 1)){
			//Console.OUT.print("\n\t*time(market"+this.markets(i).id+"):");
			val recent:ArrayList[Double] = new ArrayList[Double](0);
			for(var j:Long = 0; j < timeSize; j++){
				val r = ( markets(i).fundamentalPrices(T + (j+1-timeSize)*SomeDays*this.numStepsOneDay) - markets(i).fundamentalPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay) ) / markets(i).fundamentalPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay);
				//Console.OUT.print((T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)+"");
				//Console.OUT.print("("+r+"),");
				recent.add(r);
			}
			//Console.OUT.print("\n");
			recents.put(markets(i),recent);
		}

		return recents;
	}


	//今期の時間TimeとtimeSizeを基に、TPORT日毎のtimeSize個の各市場の理論価格の変化率を獲得する。 
	public def recentFundamentalLogReturnsTPORT(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalLogReturnsSomeDays(Time, this.TPORT, timeSize, markets);
	}

	//今期の時間TimeとtimeSizeを基に、月次のtimeSize個の各市場の理論価格の変化率を獲得する。 
	public def recentFundamentalLogReturnsOneMonth(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalLogReturnsSomeDays(Time, this.numDaysOneMonth, timeSize, markets);
	}

	//今期の時間TimeとtimeSizeを基に、日次のtimeSize個の各市場の理論価格の変化率を獲得する。 
	public def recentFundamentalLogReturnsOneDay(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentFundamentalLogReturnsSomeDays(Time, 1, timeSize, markets);
	}

	//今期の時間TimeとSomeDays,timeSizeを基に、SomeDays日毎のtimeSize個の各市場の理論価格の変化率を獲得する。 
	public def recentFundamentalLogReturnsSomeDays(Time:Long,SomeDays:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		var recents:HashMap[Market,ArrayList[Double]] = new HashMap[Market,ArrayList[Double]](0);
		for(i in 0..(markets.size() - 1)){
			//Console.OUT.print("\n\t*time(market"+this.markets(i).id+"):");
			val recent:ArrayList[Double] = new ArrayList[Double](0);
			for(var j:Long = 0; j < timeSize; j++){
				val r = Math.log( markets(i).fundamentalPrices(T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)/markets(i).fundamentalPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay) );
				//Console.OUT.print((T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)+"");
				//Console.OUT.print("("+r+"),");
				recent.add(r);
			}
			//Console.OUT.print("\n");
			recents.put(markets(i),recent);
		}

		return recents;
	}



	//今期の時間TとtimeSizeを基に、TPORT日毎のtimeSize個の各市場の市場価格の変化率を獲得する。 
	public def recentMarketNormalReturnsTPORT(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentMarketNormalReturnsSomeDays(Time, this.TPORT, timeSize, markets);
	}

	//今期の時間TとtimeSizeを基に、月次のtimeSize個の各市場の市場価格の変化率を獲得する。 
	public def recentMarketNormalReturnsOneMonth(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentMarketNormalReturnsSomeDays(Time, this.numDaysOneMonth, timeSize, markets);
	}

	//今期の時間TとtimeSizeを基に、日次のtimeSize個の各市場の市場価格の変化率を獲得する。 
	public def recentMarketNormalReturnsOneDay(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentMarketNormalReturnsSomeDays(Time, 1, timeSize, markets);
	}

	//今期の時間TとSomeDays,timeSizeを基に、SomeDays日毎のtimeSize個の各市場の市場価格の変化率を獲得する。 
	public def recentMarketNormalReturnsSomeDays(Time:Long,SomeDays:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		var recents:HashMap[Market,ArrayList[Double]] = new HashMap[Market,ArrayList[Double]](0);
		for(i in 0..(markets.size() - 1)){
			//Console.OUT.print("\n\t*time(market"+markets(i).id+"):");
			val recent:ArrayList[Double] = new ArrayList[Double](0);
			for(var j:Long = 0; j < timeSize; j++){
				val r = ( markets(i).marketPrices(T + (j+1-timeSize)*SomeDays*this.numStepsOneDay) - markets(i).marketPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay) ) / markets(i).marketPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay);
				//Console.OUT.print((T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)+"");
				//Console.OUT.print("("+r+"),");
				recent.add(r);
			}
			//Console.OUT.print("\n");
			recents.put(markets(i),recent);
		}

		return recents;
	}



	//今期の時間TとtimeSizeを基に、TPORT日毎のtimeSize個の各市場の市場価格の変化率を獲得する。 
	public def recentMarketLogReturnsTPORT(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentMarketLogReturnsSomeDays(Time, this.TPORT, timeSize, markets);
	}

	//今期の時間TとtimeSizeを基に、月次のtimeSize個の各市場の市場価格の変化率を獲得する。 
	public def recentMarketLogReturnsOneMonth(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentMarketLogReturnsSomeDays(Time, this.numDaysOneMonth, timeSize, markets);
	}

	//今期の時間TとtimeSizeを基に、日次のtimeSize個の各市場の市場価格の変化率を獲得する。 
	public def recentMarketLogReturnsOneDay(Time:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		return recentMarketLogReturnsSomeDays(Time, 1, timeSize, markets);
	}

	//今期の時間TとSomeDays,timeSizeを基に、SomeDays日毎のtimeSize個の各市場の市場価格の変化率を獲得する。 
	public def recentMarketLogReturnsSomeDays(Time:Long,SomeDays:Long, timeSize:Long, markets:List[Market]):HashMap[Market,ArrayList[Double]]{
		val T = Time - Time%(SomeDays*this.numStepsOneDay);
		var recents:HashMap[Market,ArrayList[Double]] = new HashMap[Market,ArrayList[Double]](0);
		for(i in 0..(markets.size() - 1)){
			//Console.OUT.print("\n\t*time(market"+markets(i).id+"):");
			val recent:ArrayList[Double] = new ArrayList[Double](0);
			for(var j:Long = 0; j < timeSize; j++){
				val r = Math.log( markets(i).marketPrices(T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)/markets(i).marketPrices(T + (j-timeSize)*SomeDays*this.numStepsOneDay) );
				//Console.OUT.print((T + (j+1-timeSize)*SomeDays*this.numStepsOneDay)+"");
				//Console.OUT.print("("+r+"),");
				recent.add(r);
			}
			//Console.OUT.print("\n");
			recents.put(markets(i),recent);
		}

		return recents;
	}



	public def getTFromTS(x:Rail[Long]):Long{
		var out:Long = 0;
		out = out + x(0)*this.numDaysOneMonth*this.numStepsOneDay;
		out = out + x(1)*this.numStepsOneDay;
		out = out + x(2);
		return out;
	}

	public def getTimeStructure(t:Long, name:String):Long{
		var out:Rail[Long] = getTimeStructure(t);
		return out(timeOrder(name));
	}

	public def getTimeStructure(t:Long):Rail[Long]{
		var out:Rail[Long] = new Rail[Long](3);
		out(0) = (Math.floor((t/(this.numDaysOneMonth*this.numStepsOneDay))) as Long);
		out(1) = (Math.floor(((t%(this.numDaysOneMonth*this.numStepsOneDay))/this.numStepsOneDay)) as Long);
		out(2) = (t%this.numStepsOneDay)%this.numStepsOneDay;
		return out;
	}

	public def timeOrder(name:String):Long{
		var out:Long = -1;
		if(name.equals("Month")){
			out = 0;
		}else if(name.equals("day")){
			out = 1;
		}else if(name.equals("step")){
			out = 2;
		}else{
			assert false: "timeOrderError";
		}
		return out;
	}


	//今期の時間を獲得。
	public def getTime(markets:List[Market]):Long{
		//今期の時間tの更新
		var T:Long = Long.MAX_VALUE;
		for(market in markets){
			val t:Long = market.getTime();
			if(t <= T){ T=t; }
		}
		//Console.OUT.println("*time="+T);
		return T;
	}


	public def log(normalReturns:HashMap[Market,ArrayList[Double]],markets:List[Market]):HashMap[Market,ArrayList[Double]] {
		var out:HashMap[Market,ArrayList[Double]] = new HashMap[Market,ArrayList[Double]]();
		for (market in markets) {
			var hoge:ArrayList[Double] = log( normalReturns.get(market) );
			out.put(market, hoge);
		}
		return out;
	}

	public def log(a:List[Double]):ArrayList[Double] {
		var out:ArrayList[Double] = new ArrayList[Double](a.size());
		for (i in 0..(a.size() - 1)) {
			out.add( Math.log(a(i)) );
		}
		return out;
	}

}


