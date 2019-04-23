package plham.event;
import x10.util.Random;
import plham.Market;
import plham.Fundamentals;
import plham.main.Simulator;
import plham.util.JSON;
import plham.util.JSONRandom;

/**
 * This suddently changes the fundamental price (just changing it).
 */
public class FundamentalPriceShock implements Market.MarketEvent {

	public static NO_TIME_LENGTH = Long.MAX_VALUE / 2; // To avoid n + infinity.

	public val id:Long;
	public val name:String;
	protected val random:Random;

	public var marketId:Long;
	public var triggerTime:Long;
	public var priceChangeRate:Double;
	public var shockTimeLength:Long;

	public def this(id:Long, name:String, random:Random) {
		this.id = id;
		this.name = name;
		this.random = random;
		this.shockTimeLength = NO_TIME_LENGTH;
	}

	public def update(market:Market) {
		assert this.marketId == market.id;
		val t = market.getTime();
		if (t >= this.triggerTime && t <= this.triggerTime + this.shockTimeLength) {
			//Console.OUT.println("t="+t);
			market.fundamentalPrices(t) *= (1 + this.priceChangeRate);
		}
	}

	protected def getRandom() = random;
	
	public def setup(json:JSON.Value, sim:Simulator) {
		val random = new JSONRandom(this.getRandom());
		val market = sim.getMarketByName(json("target"));
		this.marketId = market.id;
		if (json.has("triggerTime")) {
			this.triggerTime = json("triggerTime").toLong();
		} else if (json.has("triggerDays")) {
			// It's probably a bad idea that 'numStepsOneDay', which is a toplevel element of config.json, is needed to setup FundamentalPriceShocks.";
			// Should it be fixed?
			if (! sim.CONFIG.has("numStepsOneDay")) {
				assert false : "FundamentalPriceShock: triggerDays was specified, but could not find 'numStepsOneDay'. Specify 'numStepsOneDay' in the config.";
			}
			val numStepsOneDay = sim.CONFIG("numStepsOneDay").toLong();
			val triggerDays = json("triggerDays").toLong();
			this.triggerTime = triggerDays * numStepsOneDay;
		} else {
			assert false : "Could not find triggerTime. Specify 'triggerTime' or 'triggerDays' of 'FundamentalPriceShock' in the config file.";
		}
		this.shockTimeLength = FundamentalPriceShock.NO_TIME_LENGTH;
		this.priceChangeRate = json("priceChangeRate").toDouble();
		market.addBeforeSimulationStepEvent(this);
		return this;
	}
	
	public static def register(sim:Simulator) {
		val name = "FundamentalPriceShock";
		sim.addEventInitializer(name, (id:Long, name:String, random:Random, json:JSON.Value)=>{
			return new FundamentalPriceShock(id, name, random).setup(json, sim);
		});
	}
}
