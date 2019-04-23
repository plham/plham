package samples.FatTail;
import samples.CI2002.CI2002Main;
import plham.main.SequentialRunner;
import plham.agent.FCNAgent;
import plham.Market;

public class FatTailMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		val sim = new FatTailMain();
		FCNAgent.register(sim);
		Market.register(sim);
		new SequentialRunner(sim).run(args);
	}
}
