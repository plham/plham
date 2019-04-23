package samples.Option;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;
import plham.Agent;
import plham.Market;
import plham.main.Simulator;
import plham.util.Itayose;
import plham.util.JSON;
import plham.util.JSONRandom;

public class OptionMarketCluster {
	public static def createOptionMarkets(json:JSON.Value) {
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

		val ret = new ArrayList[JSON.Value]();
        val base = json("base");
		for (strikePrice in strikePrices) {
			for (maturityTime in maturityTimes) {
				for (k in 0..1) { // Call and Put pairs
					val kindName = (k == 0) ? "Call" : "Put";
                    val config = base
                        .apply("name", "OptionMarket(kind:" + kindName + ",strikePrice:" + strikePrice + ",maturity:" + maturityTime + ")")
                        .apply("kind", kindName)
                        .apply("strikePrice", strikePrice)
                        .apply("maturity", maturityTime);
                    ret.add(config);
				}
			}
		}
		return ret;
	}
	public static def register(sim:Simulator):void {
		val className = "OptionMarketCluster";
		sim.addMarketGenerator(className, (json:JSON.Value):List[JSON.Value] => {
            return createOptionMarkets(json);
		});
	}
}

