package samples.CancelTest;
import x10.util.List;
import plham.Agent;
import plham.Env;
import plham.Market;
import samples.CancelTest.CancelFCNAgent;
import plham.util.JSON;
import plham.util.JSONRandom;
import samples.CI2002.CI2002Main;
import plham.main.SequentialRunner;

public class CancelTestMain extends CI2002Main {

	public static def main(args:Rail[String]) {
		val sim = new CancelTestMain();
		CancelFCNAgent.register(sim);
		new SequentialRunner(sim).run(args);
	}

}
