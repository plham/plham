package samples.Portfolio;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;
import x10.util.StringUtil;
import plham.Agent;
import plham.Env;
import plham.Fundamentals;
import plham.Market;
import plham.Order;
import samples.Portfolio.FCNMarkowitzPortfolioAgent;
import samples.Portfolio.FCNBaselMarkowitzPortfolioAgent;
import cassia.util.JSON;
import x10.util.Map;
import x10.util.HashMap;
import plham.main.SequentialRunner;
import plham.Main;
import plham.util.JSONRandom;
import cassia.util.random.Gaussian2;

public class FCNBaselMarkowitzCI2002Main extends FCNMarkowitzCI2002Main {

	public static def main(args:Rail[String]) {
		val sim = new FCNBaselMarkowitzCI2002Main();
		FCNMarkowitzPortfolioAgent.register(sim);
		FCNBaselMarkowitzPortfolioAgent.register(sim);
		PortfolioMarket.register(sim);
		new SequentialRunner(sim).run(args);
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

	public static def dump(y:Map[Long,Long],orderMarket:ArrayList[Market]  ){
		val n:Long = y.size();
		for(var i:Long = 0; i<n; i++ ){
			Console.OUT.print(y.get(orderMarket.get(i).id)+",");
		}
		Console.OUT.println("");
	}

}
