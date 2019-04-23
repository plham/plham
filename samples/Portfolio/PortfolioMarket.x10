package samples.Portfolio;
import plham.Market;
import plham.main.Simulator;
import plham.util.JSON;
import x10.util.ArrayList;
import plham.util.JSONRandom;
import x10.util.List;

public class PortfolioMarket extends Market {
	public static def register(sim:Simulator):void {
		val className = "PortfolioMarket";
		sim.addMarketInitializer(className, (json:JSON.Value) => {
			val numMarkets = json.has("numMarkets") ? json("numMarkets").toLong() : 1;
			val markets = new ArrayList[Market](numMarkets) as List[Market];
			val jsonrandom = new JSONRandom(sim.getRandom());
			for (i in 0 .. (numMarkets - 1)) {
				markets(i) = new PortfolioMarket().setupPortfolioMarket(json, jsonrandom, sim);
			}
			sim.GLOBAL(markets(0).name) = markets as Any; // assuming 'numMarkets' is always set to 1.
			return markets;
		});
    }
    
	public def setupPortfolioMarket(json:JSON.Value, random:JSONRandom, sim:Simulator):Market {
		setupMarket(json,random,sim);
		//Console.OUT.println("########"+this.getMarketPrice());
		//Console.OUT.println("########"+json("marketPrice"));
        //this.setInitialMarketPrice(json("marketPrice").toDouble());
        this.setInitialFundamentalPrice(json("marketPrice").toDouble());
        this.setOutstandingShares(json("outstandingShares").toLong());
		return this;
	}
}
