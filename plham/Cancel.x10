package plham;

/**
 * A cancel request of an order.
 */
public class Cancel extends Order {

	public def this(order:Order) {
		super(
		order.kind,
		order.agentId,
		order.marketId,
		order.price,
		order.volume,
		order.timeLength,
		order.timePlaced);
	}
}
