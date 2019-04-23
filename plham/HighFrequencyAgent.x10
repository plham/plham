package plham;
import x10.util.Random;

/**
 * A marker class for high-frequency trading agents.
 */
public abstract class HighFrequencyAgent extends Agent {
    public def this(id:Long, name:String, random:Random) = super(id, name, random);
}
