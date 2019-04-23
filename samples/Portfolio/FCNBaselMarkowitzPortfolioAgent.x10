package samples.Portfolio;
import x10.util.ArrayList;
import x10.util.List;
import x10.util.Random;
import plham.Agent;
import plham.IndexMarket;
import plham.Market;
import plham.Order;
import x10.util.Map;
import x10.util.HashMap;
import plham.util.Statistics;
import plham.util.RandomHelper;
import plham.util.Matrix;
import samples.Portfolio.FCNMarkowitzPortfolioAgent;
import x10.io.File;
import plham.Cancel;
import plham.Env;
import cassia.util.random.Gaussian;
import cassia.util.random.Gaussian2;
import plham.main.Simulator;
import plham.util.JSON;
import plham.Agent;
import plham.util.JSONRandom;

public class FCNBaselMarkowitzPortfolioAgent extends FCNMarkowitzPortfolioAgent {

	public var riskType:String = new String();

	public var distanceType:String = new String();

	public var confInterval:Double; 
	// Confidential interval for Value-at-Risk (VaR) or ES. [0.0,1.0]

	public var confCoEfficient:Double;

	public var numDaysVaR:Long;
	// the number of days risky-asset is owned.

	public var sizeDistVaR:Long;
	// Size (number of steps) of return (loss) distribution for VaR calculation

	public var coMarketRisk:Double;

	public var threshold:Double;

	public var isLimitVariable:Boolean;
	//If IsLimitVariable is true, we use limitOrderPriceRate. Otherwise, we use limitOrderPrice.

	public var underLimitPriceRate:Double;
	public var overLimitPriceRate:Double;
	//Version 1:
	//If( market.getBuyOrderBook().getBestPrice().isNaN || market.getBuyOrderBook().getBestPrice() < market.getMarketPrice(t)*limitMarketPriceRate ){
	//	orderPrice = market.getMarketPrice(t)*limitMarketPriceRate;
	//}
	public var underLimitPrice:Double;
	public var overLimitPrice:Double;
	//Version 2:
	//If( market.getBuyOrderBook().getBestPrice().isNaN || market.getBuyOrderBook().getBestPrice() < limitMarketPrice ){
	//	orderPrice = limitMarketPrice;
	//}

	public var normalOptimalVolumes:HashMap[Long,Long];

	//コンストラクタ

	public def this() {
		/* TIPS: To keep variables unset forces users to set them. */
	}

	public def submitOrders(markets:List[Market]):List[Order] {
			
		var optPosition:HashMap[Market,Double];
		var presentPosition:HashMap[Market,Double];
		this.allMarkets = markets;
		this.accessibleMarkets = filterMarkets(markets);
		this.orderMarket = marketOrder();

		/* This implementation is to be a test-friendly base class. */
		val orders = new ArrayList[Order]();
		val torders = new ArrayList[Order]();
		val corders = new ArrayList[Order]();

		//過去出した注文を全てキャンセル.
		var lastorders:ArrayList[Order] = this.lastOreders as ArrayList[Order];
		var numlast:Long = lastorders.size();
		for(last in lastorders.clone()){
			corders.add(new Cancel(last));
		}
		lastorders.clear();
		assert lastorders.size()==0 && corders.size() == numlast : "cancelError";

		/* 現在のステップ t */
		var t:Long = 0;
		if(this.getTime(allMarkets)>=1){
			t = this.getTime(allMarkets) -1;
		}

		if(t>=this.session0iterationDays*this.numStepsOneDay){ 

			if (DEBUG == -3) {
				Console.OUT.println("#id:"+ this.id);
				//Console.OUT.println("#\tweight:"+this.fundamentalWeight+","+this.chartWeight+","+ this.noiseWeight);
			}	

			val orderTimeWindowSize:Long =this.TPORT*this.numStepsOneDay*this.timeWindowSize;

			//今期の時間を基に最適ポジションを更新するかを判断。
			//前回の更新からTPORT経っていたら，バーゼル規制なしの最適ポジション，lastUpdatedなどを更新。
			if(checkUpdateExpectation(t) ){ updateOptimalVolumes(t); }
			

				val presentVolumes = FCNMarkowitzPortfolioAgent.translation7(this.assetsVolumes,this.orderMarket);

				val presentPricesStep = presentMarketPricesStep(t);
				val presentZStep = getZ(presentPricesStep);
				val presentMarketPortfolioStep = FCNMarkowitzPortfolioAgent.getPF( presentVolumes, translation6( presentPricesStep,this.orderMarket ) ,presentZStep);

				val presentPricesDay = presentMarketPricesOneDay(t);
				val presentZDay = getZ(presentPricesDay);
				val presentMarketPortfolioDay = FCNMarkowitzPortfolioAgent.getPF( presentVolumes, translation6( presentPricesDay,this.orderMarket ) ,presentZDay);

				val presentPricesMonth = presentMarketPricesOneMonth(t);
				val presentZMonth = getZ(presentPricesMonth);
				val presentMarketPortfolioMonth = FCNMarkowitzPortfolioAgent.getPF( presentVolumes, translation6( presentPricesMonth,this.orderMarket ) ,presentZMonth);

				val presentPricesTPORT = presentMarketPricesTPORT(t);
				val presentZTPORT = getZ(presentPricesTPORT);
				val presentMarketPortfolioTPORT = FCNMarkowitzPortfolioAgent.getPF( presentVolumes, translation6( presentPricesTPORT,this.orderMarket ) ,presentZTPORT);

			if (DEBUG == -3) {
/*
				Console.OUT.println("#portfolioAgt"+this.id+":");
				Console.OUT.println("##presentVolume:");
				Console.OUT.print("##");
				Matrix.dump(presentVolumes);
				Console.OUT.println("##=========step");
				Console.OUT.println("##presentZ: "+ presentZStep);
				Console.OUT.println("##presentPF:");
				Console.OUT.print("##");
				Matrix.dump( presentMarketPortfolioStep );
				Console.OUT.println("##presentRatio:");
				Console.OUT.print("##");
				Matrix.dump( Matrix.multiply( (1/presentZStep), presentMarketPortfolioStep ) );
*/	/*			Console.OUT.println("##=========day");

				Console.OUT.println("##presentZ: "+ presentZDay);
				Console.OUT.println("##presentPF:");
				Console.OUT.print("##");
				Matrix.dump( presentMarketPortfolioDay );
				Console.OUT.println("##presentRatio:");
				Console.OUT.print("##");
				Matrix.dump( Matrix.multiply( (1/presentZDay), presentMarketPortfolioDay ) );
				Console.OUT.println("##=========Month");

				Console.OUT.println("##presentZ: "+ presentZMonth);
				Console.OUT.println("##presentPF:");
				Console.OUT.print("##");
				Matrix.dump( presentMarketPortfolioMonth );
				Console.OUT.println("##presentRatio:");
				Console.OUT.print("##");
				Matrix.dump( Matrix.multiply( (1/presentZMonth), presentMarketPortfolioMonth ) );
*/ /*				Console.OUT.println("##=========TPORT");

				Console.OUT.println("##presentZ: "+ presentZTPORT);
				Console.OUT.println("##presentPF:");
				Console.OUT.print("##");
				Matrix.dump( presentMarketPortfolioTPORT );
				Console.OUT.println("##presentRatio:");
				Console.OUT.print("##");
				Matrix.dump( Matrix.multiply( (1/presentZTPORT), presentMarketPortfolioTPORT ) );


				var opt:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(this.optimalVolumes,this.orderMarket);
				var pv:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(this.assetsVolumes,this.orderMarket);
				Console.OUT.println("##numlast:"+ numlast);
				Console.OUT.println("#**Optimal:");
				Console.OUT.print("#");
				Matrix.dump(opt);
				Console.OUT.println("#**presentVolume:");
				Console.OUT.print("#");
				Matrix.dump(pv);
*/			}

			//ここまではportfolioAgentと一緒.

			optPosition = FCNMarkowitzPortfolioAgent.translation8(this.optimalVolumes,orderMarket);
			presentPosition = FCNMarkowitzPortfolioAgent.translation8(this.assetsVolumes,orderMarket);


			var checkInitialSet2:Boolean = false;
			var checkBaselOptViolation:Boolean = false;
			var checkBaselPresentViolation:Boolean =false;

			//tport次,月次, 日次とstep次で財を少なくとも一つは売り買いできる総資産がある．
			if( presentZStep >=  Matrix.minimum(translation6(presentPricesStep,this.orderMarket)) 
			&& presentZDay >=  Matrix.minimum(translation6(presentPricesDay,this.orderMarket))
			&& presentZMonth >= Matrix.minimum(translation6(presentPricesMonth,this.orderMarket))
			&& presentZTPORT >= Matrix.minimum(translation6(presentPricesTPORT,this.orderMarket)) 
			){

				val optPosition2 = translation4(this.optimalVolumes as Map[Long,Long],this.orderMarket);
				val presentPosition2 = translation4(this.assetsVolumes as Map[Long,Long],this.orderMarket);
				val p = translation6(presentPricesDay,this.orderMarket);

				val recentMarketReturns:HashMap[Market,ArrayList[Double]];
				if(this.logType){
					recentMarketReturns = recentMarketLogReturnsOneDay(t, this.sizeDistVaR);
				}else{
					recentMarketReturns = recentMarketNormalReturnsOneDay(t, this.sizeDistVaR);
				}
				val expectedPortRisk =  translation12(expectedPortRisk(recentMarketReturns), this.orderMarket);

				val size = this.numDaysVaR as Double;
				val coEf = this.confCoEfficient;
				val c1 = presentZDay/(this.coMarketRisk*this.threshold);

				if(this.riskType.equals("VaR")){
					//checkBaselOptViolation = !CapitalToRiskRatioVaR(t, optPosition, threshold, coMarketRisk, false);
					//checkBaselPresentViolation = !CapitalToRiskRatioVaR(t, presentPosition, threshold, coMarketRisk, false);
					checkBaselOptViolation = !boundBaselGaussBooleanVaR(optPosition2, p, expectedPortRisk, size, coEf, c1);
					checkBaselPresentViolation = !boundBaselGaussBooleanVaR(presentPosition2, p, expectedPortRisk, size, coEf, c1);
				}else if(this.riskType.equals("ES")){
					//checkBaselOptViolation = !CapitalToRiskRatioES(t, optPosition, threshold, coMarketRisk, false);
					//checkBaselPresentViolation = !CapitalToRiskRatioES(t, presentPosition, threshold, coMarketRisk, false);
					checkBaselOptViolation = !boundBaselGaussBooleanES(optPosition2, p, expectedPortRisk, size, coEf, c1);
					checkBaselPresentViolation = !boundBaselGaussBooleanES(presentPosition2, p, expectedPortRisk, size, coEf, c1);
				}else{
					//checkBaselOptViolation = !CapitalToRiskRatioVaR(t, optPosition, threshold, coMarketRisk, false);
					//checkBaselPresentViolation = !CapitalToRiskRatioVaR(t, presentPosition, threshold, coMarketRisk, false);
					checkBaselOptViolation = !boundBaselGaussBooleanVaR(optPosition2, p, expectedPortRisk, size, coEf, c1);
					checkBaselPresentViolation = !boundBaselGaussBooleanVaR(presentPosition2, p, expectedPortRisk, size, coEf, c1);
					checkInitialSet2 = true;
				}

				//規制なしの最適ポジションがバーゼル規制にひっかかるなら，規制にひっかからないポジションの中で規制なしの最適ポジションに最も近いポジションを目標ポジションとする.
				//もし規制に引っかからないならば，前回更新した際の規制なしの最適ポジションをそのまま目標ポジションとする.
				if( checkBaselOptViolation ){
					if(DEBUG == -3 || DEBUG == -4 ){
						if(checkInitialSet2){
							Console.OUT.print("##VaRBaselOptViolation");
							//Console.OUT.println(":(riskType is not set. we use default setting: VaR)");
						}else{
							Console.OUT.println("##" + this.riskType + "BaselOptViolation");
						}
					}
					this.optimalVolumes = FCNMarkowitzPortfolioAgent.translation2(changeOptimalVolumes2(FCNMarkowitzPortfolioAgent.translation3(this.optimalVolumes,this.orderMarket), t,  threshold, coMarketRisk, false),this.orderMarket);
/*

					var basel:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(this.optimalVolumes,this.orderMarket);
					var normal:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(this.normalOptimalVolumes,this.orderMarket);
					if (DEBUG == -3) {
						Console.OUT.println("##"+ this.riskType +"BaselOptimal:");
						Console.OUT.print("##");
						Matrix.dump(basel);
						Console.OUT.println("##normalOpt:");
						Console.OUT.print("##");
						Matrix.dump(normal);
					}
	
					for(var i:Long = 0; i<this.orderMarket.size(); i++){
						if(  Math.abs(basel(i)) > Math.abs(normal(i))  ){
							assert false: "baselCoreError1:"+basel(i)+","+normal(i);
						}
						if(  normal(i) >= 0 && basel(i) < 0  ){
							assert false: "baselCoreError2:"+basel(i)+","+normal(i);
						}
						if(  normal(i) <= 0 && basel(i) > 0 ){
							assert false: "baselCoreError3:"+basel(i)+","+normal(i);
						}
					}
*/	


				}else{
					if(DEBUG == -3  ){
						Console.OUT.print("##BaselOptNoViolation");
					}
					this.optimalVolumes = this.normalOptimalVolumes;
				}
				if(this.riskType.equals("VaR")){
					//val print = !CapitalToRiskRatioVaR(t, optPosition, threshold, coMarketRisk, (DEBUG == -3 || DEBUG == -4 ) );
				}else if(this.riskType.equals("ES")){
					//val print = !CapitalToRiskRatioES(t, optPosition, threshold, coMarketRisk, (DEBUG == -3 || DEBUG == -4 ) );
				}else{
					//val print = !CapitalToRiskRatioVaR(t, optPosition, threshold, coMarketRisk, (DEBUG == -3 || DEBUG == -4 ) );
				}

				//今期の現在のポジションがバーゼル規制にひっかかっているなら成行，そうでなければ予想価格による指値注文をする．
				if( checkBaselPresentViolation ){
					if(DEBUG == -3 || DEBUG == -4  ){
						if(checkInitialSet2){
							Console.OUT.print("##VaRBaselPresentViolation");
							//Console.OUT.println(":(riskType is not set. we use default setting: VaR)");
						}else{
							Console.OUT.println("##" + this.riskType + "BaselPresentViolation");
						}
						//val print = !CapitalToRiskRatioES(t, presentPosition, threshold, coMarketRisk, true);
					}
					this.orderPrices = FCNMarkowitzPortfolioAgent.translation1(changeOrderPrices(t),this.orderMarket);
				}else{
					if(DEBUG == -3  ){
						Console.OUT.print("##BaselPresentNoViolation");
						//val print = !CapitalToRiskRatioES(t, presentPosition, threshold, coMarketRisk, true);
					}
					this.orderPrices = this.expectedPrices;
				}
				if(this.riskType.equals("VaR")){
					//val print = !CapitalToRiskRatioVaR(t, presentPosition, threshold, coMarketRisk, (DEBUG == -3 || DEBUG == -4 ) );
				}else if(this.riskType.equals("ES")){
					//val print = !CapitalToRiskRatioES(t, presentPosition, threshold, coMarketRisk, (DEBUG == -3 || DEBUG == -4 ) );
				}else{
					//val print = !CapitalToRiskRatioVaR(t, presentPosition, threshold, coMarketRisk, (DEBUG == -3 || DEBUG == -4 ) );
				}

			}
			var opt:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(this.optimalVolumes,this.orderMarket);
			var pv:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(this.assetsVolumes,this.orderMarket);
			if(DEBUG == -3  ){
				Console.OUT.println("##numlast:"+ numlast);
				Console.OUT.println("#**Optimal:");
				Console.OUT.print("#");
				Matrix.dump(opt);
				Console.OUT.println("#**presentVolume:");
				Console.OUT.print("#");
				Matrix.dump(pv);
			}


			//marketにアクセス不能か，もしくは，総資産が一番安い商品すら買えない金額だったら，あるmarketへの注文はゼロとする(詳細はplaceOrders参照)
			for (market in markets) {
				torders.addAll(this.placeOrders(market,t, orderTimeWindowSize));
			}
		}
		lastorders.addAll(torders);
		orders.addAll(corders);
		orders.addAll(torders);
		return orders;
	}

	public def checkNumOrdersVolumes(opt:Rail[Long], pv:Rail[Long]):boolean{
		assert opt.size == pv.size : "checkNumOrdersVolumesError";
		val n =  opt.size;
		var out2:Long = 0;
		for(i in 0..(n-1)){
			out2 = out2 +Math.abs(opt(i)-pv(i));
		}
		if(out2>0){
			return true;
		}else{
			return false;
		}
	}


	public def changeOrderPrices(time:Long):HashMap[Market,Double]{
		val dayFirst = time - time%this.numStepsOneDay;
		var out:HashMap[Market,Double] = new HashMap[Market,Double]();
		for(var i:Long = 0; i<orderMarket.size(); i++){
			var orderVolume:Long = this.getOptimalVolumes(orderMarket.get(i)) - this.getAssetVolume(orderMarket.get(i));
			var limitUnderOrderPrice:Double;
			var limitOverOrderPrice:Double;
			if(this.isLimitVariable){
				limitUnderOrderPrice = orderMarket.get(i).getMarketPrice(dayFirst)*this.underLimitPriceRate;
				limitOverOrderPrice  = orderMarket.get(i).getMarketPrice(dayFirst)*this.overLimitPriceRate;
			}else{
				limitUnderOrderPrice = this.underLimitPrice;
				limitOverOrderPrice  = this.overLimitPrice;				
			}

			if(orderVolume>0){
				if( orderMarket.get(i).getSellOrderBook().getBestPrice().isNaN() /* || orderMarket.get(i).getSellOrderBook().getBestPrice() > limitOverOrderPrice */ ){
					out.put(orderMarket.get(i),limitOverOrderPrice);
				}else{
					out.put(orderMarket.get(i),orderMarket.get(i).getSellOrderBook().getBestPrice());
				}
			}else if(orderVolume<0){
				if( orderMarket.get(i).getBuyOrderBook().getBestPrice().isNaN() /* || orderMarket.get(i).getBuyOrderBook().getBestPrice() < limitUnderOrderPrice */ ){
					out.put(orderMarket.get(i),limitUnderOrderPrice);
				}else{
					out.put(orderMarket.get(i),orderMarket.get(i).getBuyOrderBook().getBestPrice());
				}
			}
		}

		return out;
	}

	public def updateOptimalVolumes(Time:Long):void{
		val TPORTFirst = Time - Time%(this.TPORT*this.numStepsOneDay);
		super.updateOptimalVolumes(TPORTFirst);
		this.normalOptimalVolumes = this.optimalVolumes;

		this.orderPrices = this.expectedPrices;
	}

	public def changeOptimalVolumes2(position:HashMap[Market,Long], t:Long,threshold:Double, coMarketRisk:Double, print:Boolean ):HashMap[Market,Long]{
		val dayFirst = t - t%this.numStepsOneDay;
		var y:HashMap[Market,Long] = new HashMap[Market,Long]();
		y = boundVector(dayFirst);
		y = maximizedBaselVector(y ,dayFirst);

		if(this.riskType.equals("VaR")){
			//if(CapitalToRiskRatioVaR(t, translation8( translation2(y,this.orderMarket), this.orderMarket) , threshold, coMarketRisk, print)){
				return y;
			//}else{
				//assert false:"changeOptimalVolumes2Error";
				//return y;	
			//}
		}else if(this.riskType.equals("ES")){
			//if(CapitalToRiskRatioES(t, translation8( translation2(y,this.orderMarket), this.orderMarket), threshold, coMarketRisk, print)){
				return y;
			//}else{
				//assert false:"changeOptimalVolumes2Error";
				//return y;	
			//}
		}else{
			//if(CapitalToRiskRatioVaR(t,  translation8( translation2(y,this.orderMarket), this.orderMarket), threshold, coMarketRisk, print)){
				return y;
			//}else{
				//assert false:"changeOptimalVolumes2Error";
				//return y;	
			//}
		}
	}

	public def maximizedBaselVector(init:HashMap[Market,Long] ,t:Long):HashMap[Market,Long] {
		var out:HashMap[Market,Long] = new HashMap[Market,Long](0);
		var candidates:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();
		var x:Rail[Long] = translation7(translation2(init, orderMarket) as Map[Long,Long], orderMarket);
		var lastValue:Double = 0.0;
		//Console.OUT.println("##init:");
		//dump(init,orderMarket);
		out= init;
		if(this.riskType.equals("VaR")){
			var max:Double =0.0;
			var count:Long = 0;
			do{
				count++;
				lastValue =targetFunction(out);

				//xからチェビシェフ距離が1のポジション全てを取ってくる.
				candidates = FCNBaselMarkowitzPortfolioAgent.getChebyshevDistanceNeighbor(x, orderMarket, 1);

				candidates.add(out);
				candidates =  FCNMarkowitzPortfolioAgent.getLongConstrainedCandidates(candidates,this.C,this.D, this.orderMarket);
				candidates =  getLongBaselCandidates(candidates,t);
				//Console.OUT.println("**candidates2(count:"+count+"):");
				/*for(var i:Long = 0; i<candidates.size(); i++){
					Console.OUT.println("***hoge"+i);
					Matrix.dump(FCNMarkowitzPortfolioAgent.translation5(candidates.get(i),orderMarket));
					max = targetFunction(candidates.get(i));
					Console.OUT.println("****value:"+max +"\n" );
				}*/
				out = argMaximize(candidates);
				//Console.OUT.println("**out");
				//Matrix.dump(FCNMarkowitzPortfolioAgent.translation5(out,orderMarket));
			}while( lastValue < targetFunction(out) );	
		}else if(this.riskType.equals("ES")){
			do{
				lastValue =targetFunction(out);
				//xからチェビシェフ距離が1のポジション全てを取ってくる.
				candidates = FCNBaselMarkowitzPortfolioAgent.getChebyshevDistanceNeighbor(x, orderMarket, 1);

				candidates.add(out);
				candidates =  FCNMarkowitzPortfolioAgent.getLongConstrainedCandidates(candidates,this.C,this.D, this.orderMarket);
				candidates =  getLongBaselCandidates(candidates,t);
				out = argMaximize(candidates);

			}while( lastValue < targetFunction(out) );
		}else{
			do{
				lastValue =targetFunction(out);
				//xからチェビシェフ距離が1のポジション全てを取ってくる.
				candidates = FCNBaselMarkowitzPortfolioAgent.getChebyshevDistanceNeighbor(x, orderMarket, 1);

				candidates.add(out);
				candidates =  FCNMarkowitzPortfolioAgent.getLongConstrainedCandidates(candidates,this.C,this.D, this.orderMarket);
				candidates =  getLongBaselCandidates(candidates,t);
				out = argMaximize(candidates);
			}while( lastValue < targetFunction(out) );	
		}
		return out;
	}

	public def getLongBaselCandidates(before:ArrayList[HashMap[Market,Long]],t:Long):ArrayList[HashMap[Market,Long]]{
		var out:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();
		val recentMarketReturns:HashMap[Market,ArrayList[Double]];
		if(this.logType){
			recentMarketReturns = recentMarketLogReturnsOneDay(t, this.sizeDistVaR);
		}else{
			recentMarketReturns = recentMarketNormalReturnsOneDay(t, this.sizeDistVaR);
		}
		var expectedRisk:Rail[Rail[Double]] =  translation12(expectedPortRisk(recentMarketReturns), this.orderMarket);

		var prices:Rail[Double] = translation6(presentMarketPricesOneDay(t), this.orderMarket);
		val Z = getZ(presentMarketPricesOneDay(t));
		var c1:Double = Z/(coMarketRisk*threshold);
		if(this.riskType.equals("VaR")){
			for(var i:Long = 0; i<before.size(); i++){
				val x = translation0(translation7(translation2(before.get(i), orderMarket) as Map[Long,Long], orderMarket));
				if(boundBaselGaussBooleanVaR(x, prices, expectedRisk, this.numDaysVaR as Double, this.confCoEfficient ,c1 )){
					out.add(before.get(i));
				}
			}
		}else if(this.riskType.equals("ES")){
			for(var i:Long = 0; i<before.size(); i++){
				val x = translation0(translation7(translation2(before.get(i), orderMarket) as Map[Long,Long], orderMarket));
				if(boundBaselGaussBooleanES(x, prices, expectedRisk, this.numDaysVaR as Double, this.confCoEfficient ,c1 )){
					out.add(before.get(i));
				}
			}
		}else{
			for(var i:Long = 0; i<before.size(); i++){
				val x = translation0(translation7(translation2(before.get(i), orderMarket) as Map[Long,Long], orderMarket));
				if(boundBaselGaussBooleanVaR(x, prices, expectedRisk, this.numDaysVaR as Double, this.confCoEfficient ,c1 )){
					out.add(before.get(i));
				}
			}
		}
		return out;
	}

	public def boundVector(dayFirst:Long):HashMap[Market,Long]{
		val recentMarketReturns:HashMap[Market,ArrayList[Double]];
		if(this.logType){
			recentMarketReturns = recentMarketLogReturnsOneDay(dayFirst, this.sizeDistVaR);
		}else{
			recentMarketReturns = recentMarketNormalReturnsOneDay(dayFirst, this.sizeDistVaR);
		}
		var expectedRisk:Rail[Rail[Double]] =  translation12(expectedPortRisk(recentMarketReturns), this.orderMarket);

		var prices:Rail[Double] = translation6(presentMarketPricesOneDay(dayFirst), this.orderMarket);
		val Z = getZ(presentMarketPricesOneDay(dayFirst));
		var c1:Double = Z/(coMarketRisk*threshold);

		val initial = translation7(this.optimalVolumes, this.orderMarket);

		var size:Double = this.numDaysVaR as Double;

		//Console.OUT.println("#conf="+ this.confCoEfficient+",sizeDistVaR="+this.sizeDistVaR);

		var candidates:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();
		var x:Rail[Long] = initial;
		var distance:Long = 0;

		if(this.riskType.equals("VaR")){
			do{
				//xからチェビシェフ距離が1のポジション全てを取ってくる.
				candidates = FCNBaselMarkowitzPortfolioAgent.getChebyshevDistanceNeighbor(x, orderMarket, 1);

				candidates =  FCNMarkowitzPortfolioAgent.getLongConstrainedCandidates(candidates,this.C,this.D, this.orderMarket);
				x = argMinimizeGaussVaR(candidates, prices, expectedRisk, size, this.confCoEfficient, c1);
				distance++;

			        //Console.OUT.print("#y:");
			        //Matrix.dump(x);
			        //Console.OUT.print("#basel:"+ boundBaselGaussValueVaR(translation0(x), prices, expectedRisk, size, this.confCoEfficient, c1) );
			        //Console.OUT.println("");
			}while( !boundBaselGaussBooleanVaR(translation0(x), prices, expectedRisk, size, this.confCoEfficient, c1) );	
		}else if(this.riskType.equals("ES")){
			do{
				//xからチェビシェフ距離が1のポジション全てを取ってくる.
				candidates = FCNBaselMarkowitzPortfolioAgent.getChebyshevDistanceNeighbor(x, orderMarket, 1);

				candidates =  FCNMarkowitzPortfolioAgent.getLongConstrainedCandidates(candidates,this.C,this.D, this.orderMarket);
				x = argMinimizeGaussES(candidates, prices, expectedRisk, size, this.confCoEfficient, c1);
				distance++;
			}while( !boundBaselGaussBooleanES(translation0(x), prices, expectedRisk, size, this.confCoEfficient, c1) );
		}else{
			do{
				//xからチェビシェフ距離が1のポジション全てを取ってくる.
				candidates = FCNBaselMarkowitzPortfolioAgent.getChebyshevDistanceNeighbor(x, orderMarket, 1);

				candidates =  FCNMarkowitzPortfolioAgent.getLongConstrainedCandidates(candidates,this.C,this.D, this.orderMarket);
				x = argMinimizeGaussVaR(candidates, prices, expectedRisk, size, this.confCoEfficient, c1);
				distance++;
			}while( !boundBaselGaussBooleanVaR(translation0(x), prices, expectedRisk, size, this.confCoEfficient, c1) );	
		}
	        //Console.OUT.print("#y:");
	        //Matrix.dump(x);
	        //Console.OUT.print("#basel:"+ boundBaselGaussValueVaR(translation0(x), prices, expectedRisk, size, this.confCoEfficient, c1) );
		//Console.OUT.println("");
		return translationm1(x,orderMarket);
	}


	//ES用
	public def argMinimizeGaussES(candidates:ArrayList[HashMap[Market,Long]], p:Rail[Double], expectedPortRisk:Rail[Rail[Double]], size:Double, coEf:Double ,c1:Double ):Rail[Long]{
		var out:Rail[Long] = new Rail[Long](0);
		var targetMax:Double = Double.POSITIVE_INFINITY;
		var trueCands:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]](0);
		for(c in candidates){
			val c2 = translation7(translation2(c,orderMarket),orderMarket);
			val targetC:Double = boundBaselGaussValueES(translation0(c2), p, expectedPortRisk, size, coEf ,c1);
			if(targetC >0.0 && targetC <= targetMax){
				targetMax = targetC;
				out = c2;
			}else if(targetC <=0.0){
				trueCands.add(c);
			}
		}

		if(trueCands.size()==0){
			return out;
		}else{
			val c = argMaximize(trueCands);
			return  translation7(translation2(c,orderMarket),orderMarket);
		}
	}

	//VaR用
	public def argMinimizeGaussVaR(candidates:ArrayList[HashMap[Market,Long]], p:Rail[Double], expectedPortRisk:Rail[Rail[Double]], size:Double, coEf:Double ,c1:Double ):Rail[Long]{
		var out:Rail[Long] = new Rail[Long](0);
		var targetMax:Double = Double.POSITIVE_INFINITY;
		var trueCands:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]](0);
		for(c in candidates){
			val c2 = translation7(translation2(c,orderMarket),orderMarket);
			val targetC:Double = boundBaselGaussValueVaR(translation0(c2), p, expectedPortRisk, size, coEf ,c1);
			if(targetC >0.0 && targetC <= targetMax){
				targetMax = targetC;
				out = c2;
			}else if(targetC <=0.0){
				trueCands.add(c);
			}
		}
		if(trueCands.size()==0){
			return out;
		}else{
			val c = argMaximize(trueCands);
			return  translation7(translation2(c,orderMarket),orderMarket);
		}
	}

	//ES基準での近似関数用いた形でのESのバーゼル規制にひっかからなければtrue
	public def boundBaselGaussBooleanES(x:Rail[Double], p:Rail[Double], expectedPortRisk:Rail[Rail[Double]], size:Double, coEf:Double ,c1:Double ):Boolean{
		val hoge = boundBaselGaussValueES(x, p, expectedPortRisk, size, coEf,c1 );
		if( hoge> 0.0  ){
			return false;
		}else{
			return true;
		}
	}

	//VaR基準での近似関数用いた形でのESのバーゼル規制にひっかからなければtrue
	public def boundBaselGaussBooleanVaR(x:Rail[Double], p:Rail[Double], expectedPortRisk:Rail[Rail[Double]], size:Double, coEf:Double ,c1:Double ):Boolean{
		val hoge = boundBaselGaussValueVaR(x, p, expectedPortRisk, size, coEf,c1 );
		if( hoge> 0.0 ){
			return false;
		}else{
			return true;
		}
	}


	//この関数の値が正のときにはxは近似関数用いた形でのESのバーゼル規制に引っかかる.
	public def boundBaselGaussValueES(x:Rail[Double], p:Rail[Double], expectedPortRisk:Rail[Rail[Double]], size:Double, coEf:Double ,c1:Double ):Double{
		var out:Double;
		var VaR:Double = Math.pow( size*Matrix.multiply(Matrix.multiply(expectedPortRisk,x),x),0.5)*coEf;
		val delta = Math.pow(10,-5);
		VaR = VaR - VaR.operator%(delta);
		VaR= -1.0*VaR;
		val nlim:Double = -1.0*Math.pow(10,5);
		var ES:Double = Gaussian2.gaussExpectedValue(nlim, VaR, delta, 0.0, size*Math.pow( Matrix.multiply(Matrix.multiply(expectedPortRisk,x),x), 0.5) );
		if(this.logType){
			if( Matrix.multiply(p,x) > 0){
				out = Matrix.multiply(p,x)*(1.0 - Math.exp(ES) ) -c1;
			}else if( Matrix.multiply(p,x) < 0  ){
				out = Matrix.multiply(p,x)*(1.0 - Math.exp(-1.0*ES) ) -c1;
			}else{
				out = 0.0;
			}
		}else{
			if( Matrix.multiply(p,x) > 0){
				out = -1.0*Matrix.multiply(p,x)*ES -c1;
			}else if( Matrix.multiply(p,x) < 0  ){
				out = Matrix.multiply(p,x)*ES -c1;
			}else{
				out = 0.0;
			}
		}
		return out;	
	}

	//この関数の値が正のときにはxは近似関数用いた形でのVaRのバーゼル規制に引っかかる.
	public def boundBaselGaussValueVaR(x:Rail[Double], p:Rail[Double], expectedPortRisk:Rail[Rail[Double]], size:Double, coEf:Double ,c1:Double ):Double{
		var out:Double;
		var VaR:Double = Math.pow( size*Matrix.multiply(Matrix.multiply(expectedPortRisk,x),x),0.5)*coEf;
		VaR= -1.0*VaR;
		if(this.logType){
			if( Matrix.multiply(p,x) > 0){
				out = Matrix.multiply(p,x)*(1.0 - Math.exp(VaR) ) -c1;
			}else if( Matrix.multiply(p,x) < 0  ){
				out = Matrix.multiply(p,x)*(1.0 - Math.exp(-1.0*VaR) ) -c1;
			}else{
				out = 0.0;
			}
		}else{
			if( Matrix.multiply(p,x) > 0){
				out = -1.0*Matrix.multiply(p,x)*VaR -c1;
			}else if( Matrix.multiply(p,x) < 0  ){
				out =  1.0*Matrix.multiply(p,x)*VaR -c1;
			}else{
				out = 0.0;
			}
		}
		return out;
	}

	public def expectedPortRisk(recentMarketReturnsT:HashMap[Market,ArrayList[Double]]):HashMap[Market,HashMap[Market,Double]]{
		var out1:HashMap[Market,HashMap[Market,Double]] = new HashMap[Market,HashMap[Market,Double]]();

		//リターンの平均を計算
		var aves:Map[Market,Double] = new HashMap[Market,Double]();

		for(i in 0..(this.orderMarket.size() - 1)){
			var ave:Double =0;
			val recentMarketReturns = recentMarketReturnsT.get(orderMarket.get(i));
	   		for(var j:Long = 0; j < recentMarketReturns.size(); ++j){
				ave = ave + recentMarketReturns(j);
			}
			ave = ave/(recentMarketReturns.size() as Double );
			aves.put(orderMarket.get(i), ave);
		}
		//分散共分散を計算しoutに格納.
		for(i in 0..(this.orderMarket.size() - 1)){
			var med:HashMap[Market,Double] = new HashMap[Market,Double](); 
			for(j in 0..(this.orderMarket.size() - 1)){
				val recentMarketReturns1 = recentMarketReturnsT.get(orderMarket.get(i));
				val recentMarketReturns2 = recentMarketReturnsT.get(orderMarket.get(j));
				assert recentMarketReturns1.size() == recentMarketReturns2.size()  : "sizeError";
				var risk:Double = 0;
 				for(var k:Long = 0; k < recentMarketReturns1.size(); ++k){
					risk = risk + (aves.get(orderMarket.get(i)) - recentMarketReturns1(k) )* (aves.get(orderMarket.get(j)) - recentMarketReturns2(k) );
				}
				risk = risk/(recentMarketReturns1.size()-1);
				med.put(orderMarket.get(j),risk);
			}
			out1.put(orderMarket.get(i),med);
		}
		return out1;
	}

	public static def removeArrayList(base:ArrayList[HashMap[Market,Long]], news:ArrayList[HashMap[Market,Long]], orderMarket:ArrayList[Market]):ArrayList[HashMap[Market,Long]]{
		var base2:ArrayList[HashMap[Market,Long]] =new ArrayList[HashMap[Market,Long]]();
		for(y in base){
			base2.add(y);
		}
		for(x in news){
			base2 = removeArrayList(base2,x,orderMarket);
		}
		return base2;
	}

	public static def removeArrayList(base:ArrayList[HashMap[Market,Long]], newOne:HashMap[Market,Long], orderMarket:ArrayList[Market]):ArrayList[HashMap[Market,Long]]{
		var base2:ArrayList[HashMap[Market,Long]] =new ArrayList[HashMap[Market,Long]]();
		//Console.OUT.println("*newone:");
		
		for(y in base){
			if( !eqcheck(y,newOne,orderMarket) ){
				//Console.OUT.println("*true");
				base2.add(y);
			}else{
				//Console.OUT.println("*false");
			}
		}
		return base2;
	}


	public static def addALLArrayList(base:ArrayList[HashMap[Market,Long]], news:ArrayList[HashMap[Market,Long]],orderMarket:ArrayList[Market] ):ArrayList[HashMap[Market,Long]]{
		var base2:ArrayList[HashMap[Market,Long]] =new ArrayList[HashMap[Market,Long]]();

		//Console.OUT.println("**hoge of a ("+news.size()+"):");
		//for(var i:Long = 0; i<news.size(); i++){
		//	FCNMarkowitzPortfolioAgent.dump(new.get(i),orderMarket);
		//}

		for(y in base){
			base2.add(y);
		}
		for(x in news){
			base2 = addArrayList(base2,x,orderMarket);
		}
		//Console.OUT.println("*totyuucount:"+base.size()+","+base2.size());
		return base2;
	}

	public static def addArrayList(base:ArrayList[HashMap[Market,Long]], newOne:HashMap[Market,Long],orderMarket:ArrayList[Market] ):ArrayList[HashMap[Market,Long]]{
		var base2:ArrayList[HashMap[Market,Long]] =new ArrayList[HashMap[Market,Long]]();
		for(y in base){
			base2.add(y);
		}

		if(base.size()!=0){
			for(x in base){
				if( eqcheck(x,newOne,orderMarket) ){
					return base;
				}
			}
		}

		base2.add(newOne);
		return base2;
	}

	public static def eqcheck(x:HashMap[Market,Long],y:HashMap[Market,Long],orderMarket:ArrayList[Market]):boolean{
		var x2:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(FCNMarkowitzPortfolioAgent.translation2(x,orderMarket),orderMarket);
		var y2:Rail[Long] = FCNMarkowitzPortfolioAgent.translation7(FCNMarkowitzPortfolioAgent.translation2(y,orderMarket),orderMarket);
		return eqcheck(x2,y2);
	}

	public static def eqcheck(x:Rail[Long],y:Rail[Long]):boolean{
		var out:Boolean;
		/*Console.OUT.println("*x");
		Matrix.dump(x);
		Console.OUT.println("*y");
		Matrix.dump(y);*/
		if(x.size!=y.size){
			out= false;
		}else{
			var count:Long = 0;
			for(var i:Long = 0; i<x.size; i++){
				if(x(i)==y(i)){
					count++;	
				}
			}
			//Console.OUT.println("*count="+count+"="+x.size);
			if(count==x.size){
				out = true;
			}else{
				out= false;
			}
		}
		return out;
	}


	public def getLongBaselVaRConstrainedCandidates(before:ArrayList[HashMap[Market,Long]], t:Long):ArrayList[HashMap[Market,Long]]{
		val dayFirst = t - t%this.numStepsOneDay;
		var out:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();
		for(var i:Long = 0; i<before.size(); i++){
			var hoge:HashMap[Market,Double] = FCNMarkowitzPortfolioAgent.translation8(FCNMarkowitzPortfolioAgent.translation2(before.get(i),this.orderMarket),this.orderMarket);
			var hoge2:Rail[Double] = FCNMarkowitzPortfolioAgent.translation5(before.get(i),this.orderMarket);
			//Matrix.dump(hoge2);
			if( CapitalToRiskRatioVaR(dayFirst, hoge, threshold, coMarketRisk, false) ){
				out.add(before.get(i));
			}
		}
		return out;
	}

	public def getLongBaselESConstrainedCandidates(before:ArrayList[HashMap[Market,Long]], t:Long):ArrayList[HashMap[Market,Long]]{
		val dayFirst = t - t%this.numStepsOneDay;
		var out:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();
		for(var i:Long = 0; i<before.size(); i++){
			var hoge:HashMap[Market,Double] = FCNMarkowitzPortfolioAgent.translation8(FCNMarkowitzPortfolioAgent.translation2(before.get(i),this.orderMarket),this.orderMarket);
			var hoge2:Rail[Double] = FCNMarkowitzPortfolioAgent.translation5(before.get(i),this.orderMarket);
			//Matrix.dump(hoge2);
			if( CapitalToRiskRatioES(dayFirst, hoge, threshold, coMarketRisk, false) ){
				out.add(before.get(i));
			}
		}
		return out;
	}


	public static def getChebyshevDistanceNeighbor(x:Rail[Long], orderMarket:ArrayList[Market], distance:Long ):ArrayList[HashMap[Market,Long]]{
		var directions:ArrayList[String] = new ArrayList[String](0);
		var out:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]](0);
		var out2:ArrayList[Rail[Long]] = new ArrayList[Rail[Long]]();
		var element:String = new String();
		getPowerSet2(element,directions,1, x.size);
		val size:Long = directions.size();
		val dim:Long = orderMarket.size();
		//Console.OUT.println("*distance:"+distance);
		//Console.OUT.println("**sizeDirection:"+size);
		assert size == (Math.pow(3,dim) as Long) : "powerSetErr:"+size; 
		for(var i:Long = 0; i<size; i++){
			//Console.OUT.println("**direction("+(i+1)+"):");
			//Console.OUT.println(directions.get(i));
			var direction:Rail[Long] = new Rail[Long](dim);
			val components:Rail[String] = directions.get(i).split("_");
			for(var j:Long = 0; j<dim; j++){
				direction(j) = Long.parse( components(j) );
			}
			//Matrix.dump(direction);
			var subset:ArrayList[Rail[Long]] =shareChebyshevD(direction,distance);
			out2.addAll(subset);
		}
		/*var ct:Long = 0;
		for(var i:Long = 0; i<out2.size(); i++){
			for(var j:Long = 0; j<out2.size(); j++){
				if(eqcheck(out2.get(i),out2.get(j))){ ct++; }
			}
		}

		Console.OUT.println("**ct:"+ct);*/

		for(var i:Long = 0; i<out2.size(); i++){
			//Matrix.dump(out2.get(i));
			assert absMax(out2.get(i)) == distance:"getChebyshevDistanceNeighborError";
			val hoge0 = Matrix.plus(out2.get(i),x);
			val hoge = FCNMarkowitzPortfolioAgent.translation9(hoge0,orderMarket);
			val hoge2 = FCNMarkowitzPortfolioAgent.translation3(hoge ,orderMarket );
			out.add(hoge2);
			//out = addArrayList(out, hoge2,orderMarket );
		}
		return out;
	}


	private static def absMax(x:Rail[Long]):Long{
		var out:Long = Long.MIN_VALUE;
		for(i in 0..(x.size - 1)){
			if( Math.abs( x(i) )  >out){
				out = Math.abs( x(i) );
			}
		}
		return out;
	}

	public static def getManhattanDistanceNeighbor(x:Rail[Long], orderMarket:ArrayList[Market], distance:Long ):ArrayList[HashMap[Market,Long]]{
		var directions:ArrayList[String] = new ArrayList[String](0);
		var out:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();
		var out2:ArrayList[Rail[Long]] = new ArrayList[Rail[Long]]();
		var element:String = new String();
		getPowerSet2(element,directions,1, x.size);
		val size:Long = directions.size();
		val dim:Long = orderMarket.size();
		//Console.OUT.println("*distance:"+distance);
		//Console.OUT.println("**sizeDirection:"+size);
		assert size == (Math.pow(3,dim) as Long) : "powerSetErr:"+size; 
		for(var i:Long = 0; i<size; i++){
			//Console.OUT.println("**direction("+(i+1)+"):");
			//Console.OUT.println(directions.get(i));
			var direction:Rail[Long] = new Rail[Long](dim);
			val components:Rail[String] = directions.get(i).split("_");
			for(var j:Long = 0; j<dim; j++){
				direction(j) = Long.parse( components(j) );
			}
			//Matrix.dump(direction);
			var subset:ArrayList[Rail[Long]] =shareManhattanD(direction,distance);
			out2.addAll(subset);
		}
		//Console.OUT.println("===result("+out2.size()+")===");

		/*var ct:Long = 0;
		for(var i:Long = 0; i<out2.size(); i++){
			for(var j:Long = 0; j<out2.size(); j++){
				if(eqcheck(out2.get(i),out2.get(j))){ ct++; }
			}
		}

		Console.OUT.println("**ct:"+ct);*/

		for(var i:Long = 0; i<out2.size(); i++){
			//Matrix.dump(out2.get(i));
			assert num(out2.get(i)) == distance:"getManhattanDistanceNeighborError";
			val hoge0 = Matrix.plus(out2.get(i),x);
			val hoge = FCNMarkowitzPortfolioAgent.translation9(hoge0,orderMarket);
			val hoge2:HashMap[Market,Long] = FCNMarkowitzPortfolioAgent.translation3(hoge ,orderMarket );
			out.add(hoge2);
			//out = addArrayList(out, hoge2,orderMarket );
		}
		return out;
	}


	private static def shareChebyshevD(direction:Rail[Long], d:Long):ArrayList[Rail[Long]]{
		var out:ArrayList[Rail[Long]] = new ArrayList[Rail[Long]]();
		val dim = direction.size;
		val num = num(direction);

		//Console.OUT.println("***num="+num);
		//Console.OUT.println("***distance="+d);

		if( d==0 && num==0 ){
			var elem:Rail[Long] = new Rail[Long](dim);
			out.add(elem);

		//この場合は，directionを満たすdistanceのshareの仕方は存在しない.
		}else if( d==0 || num == 0){
			
		}else{
			val rest:Long = dim - num;
			//Console.OUT.println("rest="+rest);
			val cb:ArrayList[String] = new ArrayList[String]();
			val max = d -1;
			getPowerSet2(new String(),cb,max, rest);
			//Console.OUT.println("cbSize="+cb.size());
			for(var i:Long = 0; i<cb.size(); i++){
				var elem:Rail[Long] = new Rail[Long](dim);
				for(var j:Long = 0; j<dim; j++){
					elem(j) = direction(j)*d;
				}
				var count:Long = 0;
				val tcb = cb.get(i).split("_");
				for(var j:Long = 0; j<dim; j++){
					if(elem(j)==0 && count < tcb.size ){
						elem(j) = Long.parse(tcb(count));
						count++;
					}
					//Console.OUT.println(elem(j));
				}
				out.add(elem);
			}
		}

		return out;
	}



	private static def shareManhattanD(direction:Rail[Long], d:Long):ArrayList[Rail[Long]]{
		var out:ArrayList[Rail[Long]] = new ArrayList[Rail[Long]]();
		val n = direction.size;
		val num = num(direction);

		//Console.OUT.println("***num="+num);
		//Console.OUT.println("***distance="+d);

		
		//この場合は，directionを満たすdistanceのshareの仕方は存在しない.
		if(d < num ){

		//この場合は，directionを満たすdistanceのshareの仕方は１種類のみ
		}else if(d == num){
			var elem:Rail[Long] = new Rail[Long](n);
			for(var j:Long = 0; j<n; j++){
				elem(j) = direction(j);
			}
			assert num(elem) == num: "shareDError0";
			out.add(elem);
			assert out.size() == 1: "shareDError1";

		//この場合(num==0 && d>num )も，directionを満たすdistanceのshareの仕方は存在しない.
		}else if( num==0 ){

		//この場合は，directionを満たすようにdistanceを1つずつ配ってから，各ケースについて考える.
		}else{
			val rest = d-num;
			//Console.OUT.println("rest="+rest);
			val cb:ArrayList[String] = new ArrayList[String]();
			getPowerSet3(new String(),cb,num,rest);
			//Console.OUT.println("cbSize="+cb.size());
			for(var i:Long = 0; i<cb.size(); i++){
				//Console.OUT.println(cb.get(i));
				//まず1以上の各財に一つずつ投入.
				var elem:Rail[Long] = new Rail[Long](n);
				var count:Long = 0;
				val tcb = cb.get(i).split("_");
				for(var j:Long = 0; j<n; j++){
					//Console.OUT.println("*****j="+j+"("+count+")");
					if(Math.abs(direction(j))!=0 && count < tcb.size ){
						elem(j) = direction(j)*(Long.parse(tcb(count))+1);
					}
					//Console.OUT.println(elem(j));
					if( direction(j)!=0 ){ count++; }
				}
				out.add(elem);
			}
		}
		//Console.OUT.println("***size="+out.size());
		/*for(var i:Long = 0; i<out.size(); i++ ){
			Matrix.dump(out.get(i));
		}*/
		return out;
	}

	private static def test3(x:Rail[Long], n:Long){
		var powerIndexSet:ArrayList[String] = new ArrayList[String](0);
		var element:String = new String();
		getPowerSet3(element,powerIndexSet, x.size, n);
		Console.OUT.println("*t="+n+":"+powerIndexSet.size());
		for(var i:Long = 0; i<powerIndexSet.size(); i++ ){
			Console.OUT.println(powerIndexSet.get(i));
		}
	}

	//rest個の資源をn人に分配するやり方すべてを要素とした集合をpowerIndexSetに返す．
	private static def getPowerSet3(element:String, powerIndexSet:ArrayList[String], n:Long,rest:Long):void{	
		var components:Rail[String] = element.split("_");
		val index:Long = components.size;
		if(n==index){
			powerIndexSet.add(element);
		}else if(n-1==index){
			getPowerSet3(element+ rest +"_", powerIndexSet, n, 0);
		}else{
			for(var j:Long =0; j<=rest; j++){
				getPowerSet3(element+ j +"_", powerIndexSet, n, (rest-j));
			}
		}
	}

	//16sub. ベクトルx:Rail[Long](n)とそのノイマン近傍3^n個のベクトルをpowerIndexSetにString形式で格納していく再帰関数。
	public static def getPowerSet2(element:String, powerIndexSet:ArrayList[String], max:Long, n:Long):void{
		assert max >=0: "getPowerSet2Error"+max;		
		var components:Rail[String] = element.split("_");
		val i:Long = components.size;
		//Console.OUT.println("*i="+i+":");
		if(i==n){
			powerIndexSet.add(element);
		}else{
			if(max > 0){
				for(var j:Long = -max; j<=max; j++ ){
					getPowerSet2(element + j + "_",powerIndexSet,max, n );
				}
			}else{
				getPowerSet2(element + "0_",powerIndexSet,max, n );
			}
		}
	}

	private static def num(direction:Rail[Long]):Long{
		var out:Long = 0;
		val n:Long = direction.size;
		for(var i:Long = 0; i<n; i++){
			out = out +Math.abs(direction(i));
		}
		return out;
	}


	//8%以上だから，ratio >= threshold ならtrue（outは正）で規制を満たす
	public def CapitalToRiskRatioVaR(t:Long, position:HashMap[Market,Double], threshold:Double, coMarketRisk:Double, print:boolean):Boolean{
		val dayFirst = t - t%this.numStepsOneDay;
		var Z:Double = getZ(presentMarketPricesOneDay(dayFirst));
		var tout:Boolean = false;
		var out:Double =0.0;
		if(Z<=0){
			assert false : "CapitalToRiskRatioVaRError";
		}else{
			var r:Double =0.0;
			var loss:Double=0.0;
			if(presentMarketPortfolioPriceOneDay(dayFirst,position)>0.0){
				r = makeMarketPortfolioReturnVaR(dayFirst, position);
				if(this.logType){
					//Console.OUT.println("##CapitallossType:log");
					loss = ( 1.0 - Math.exp(r) )*presentMarketPortfolioPriceOneDay(dayFirst,position);
				}else{
					//Console.OUT.println("##CapitallossType:normal");
					loss =  -1.0*r*presentMarketPortfolioPriceOneDay(dayFirst,position);
				}
			}else if(presentMarketPortfolioPriceOneDay(dayFirst,position)<0.0){
				r = makeMarketPortfolioReturnReverseVaR(dayFirst, position);
				if(this.logType){
					//Console.OUT.println("##CapitallossType:log");
					loss = ( 1.0 - Math.exp(r) )*presentMarketPortfolioPriceOneDay(dayFirst,position);
				}else{
					//Console.OUT.println("##CapitallossType:normal");
					loss = -1.0*r*presentMarketPortfolioPriceOneDay(dayFirst,position);
				}
			}else{
				loss = 0.0;
			}
			var ratio:Double;

			if(loss>0){
				ratio = Z/(coMarketRisk*loss);
			}else{
				ratio = Double.MAX_VALUE;
			}
			out = ratio - threshold ;
			if(Matrix.checkPositive(out)){
				if( print ){
					Console.OUT.println("##(r,loss,Z,R)=("+r+","+loss+","+Z +","+ (Z/loss) +")");
					Console.OUT.println("##(ratio,threshold)=("+ratio+","+threshold +")");
				}
				tout = true;
			}else{
				if( print ){
					Console.OUT.println("##(r,loss,Z,R)=("+r+","+loss+","+Z +","+ (Z/loss) +")");
					Console.OUT.println("##(ratio,threshold)=("+ratio+","+threshold +")");
				}
				tout = false;
			}
		}
		return tout;
	}

	//8%以上だから，ratio >= threshold ならtrue（outは正）で規制を満たす
	public def CapitalToRiskRatioES(t:Long, position:HashMap[Market,Double], threshold:Double, coMarketRisk:Double, print:boolean):Boolean{
		val dayFirst = t - t%this.numStepsOneDay;
		var Z:Double = getZ(presentMarketPricesOneDay(dayFirst));
		var out:Double =0.0;
		var tout:Boolean = false;
		if(Z<=0){
			assert false : "CapitalToRiskRatioESError";
		}else{
			var r:Double =0.0;
			var loss:Double=0.0;
			if(presentMarketPortfolioPriceOneDay(dayFirst,position)>0.0){
				r = makeMarketPortfolioReturnES(dayFirst, position);
				if(this.logType){
					//Console.OUT.println("##CapitallossType:log");
					loss = ( 1.0 - Math.exp(r) )*presentMarketPortfolioPriceOneDay(dayFirst,position);
				}else{
					//Console.OUT.println("##CapitallossType:normal");
					loss =  -1.0*r*presentMarketPortfolioPriceOneDay(dayFirst,position);
				}
			}else if(presentMarketPortfolioPriceOneDay(dayFirst,position)<0.0){
				r = makeMarketPortfolioReturnReverseES(dayFirst, position);
				if(this.logType){
					//Console.OUT.println("##CapitallossType:log");
					loss = ( 1.0 - Math.exp(r) )*presentMarketPortfolioPriceOneDay(dayFirst,position);
				}else{
					//Console.OUT.println("##CapitallossType:normal");
					loss =  -1.0*r*presentMarketPortfolioPriceOneDay(dayFirst,position);
				}
			}else{
				loss = 0.0;
			}
			var ratio:Double;

			if(loss>0){
				ratio = Z/(coMarketRisk*loss);
			}else{
				ratio = Double.MAX_VALUE;
			}
			out = ratio -threshold ;
			if(Matrix.checkPositive(out)){
				if( print ){
					Console.OUT.println("##(r,loss,Z,R)=("+r+","+loss+","+Z +","+ (Z/loss) +")");
					Console.OUT.println("##(ratio,threshold)=("+ratio+","+threshold +")");
				}
				tout = true;
			}else{
				if( print ){
					Console.OUT.println("##(r,loss,Z,R)=("+r+","+loss+","+Z +","+ (Z/loss) +")");
					Console.OUT.println("##(ratio,threshold)=("+ratio+","+threshold +")");
				}
				tout = false;
			}
		}
		return tout;
	}

	//モンテカルロ計算で1日分のリターンの分布baseからdays分の累積リターンの分布（サイズはbase.size()*multiSize）を求めるための関数
	public def multipliedDistMonte( multiSize:Long ,base:ArrayList[Double], days:Long):ArrayList[Double]{
/*		val l:ArrayList[Double] = new ArrayList[Double](0);
		for(var i:Long = 0; i<base.size(); i++){
			val x = base.get(i);
			l.add(x);
		}
		l.sort();
		for(var i:Long = 0; i<l.size(); i++){
			Console.OUT.println(l.get(i));
		}
		Console.OUT.println("");*/
		if(days==1){ return base; }
		val random = new RandomHelper(getRandom());
		var out:ArrayList[Double] = new ArrayList[Double](0);
		val s:Long = multiSize;
		for(var i:Long = 0; i<multiSize; i++){
			var hoge:Rail[Rail[Long]] = new Rail[Rail[Long]](days);
			for(var j:Long = 0; j<days; j++){
				hoge(j) = new Rail[Long](base.size());
				var flag:ArrayList[Long] = new ArrayList[Long](0);
				for(var k:Long = 0; k<base.size(); k++){ flag.add(k); }
				for(var k:Long = 0; k<base.size(); k++){ 
					val index:Long = random.nextLong(flag.size());
					val x:Long = flag.get(index);
					hoge(j)(k) = x;
					val b:boolean = flag.remove(x);
					//Console.OUT.println("#size="+flag.size());
					assert b : "multipliedDistMonteError";
				}
			}
			for(var k:Long = 0; k<base.size(); k++){
				var cumR:Double = 0.0;
				for(var j:Long = 0; j<days; j++){
					cumR = cumR + base.get( hoge(j)(k) );
				}
				out.add(cumR);
			}
		}
/*		val m:ArrayList[Double] = new ArrayList[Double](0);
		for(var i:Long = 0; i<out.size(); i++){
			val x = out.get(i);
			m.add(x);
		}
		m.sort();
		for(var i:Long = 0; i<m.size(); i++){
			Console.OUT.println(m.get(i));
		}
		Console.OUT.println("");*/
		return out;
	}

	//1日分のリターンの分布baseからdays分の累積リターンの分布を求めるための再帰関数
	public def multipliedDist( cals:ArrayList[Double], base:ArrayList[Double], days:Long):ArrayList[Double]{
		var count:Long = 0;
		do{	count++;	}while(  Long.operator_as(Math.pow(base.size(),count)) != cals.size() );
		//Console.OUT.println("#count="+count);
		if(count == days){
			return cals;
		}else if(count>days){
			assert false : "multipliedDistError";
			return new ArrayList[Double](0);
		}else{
			var ne:ArrayList[Double] = new ArrayList[Double](0);
			for(var i:Long=0; i<cals.size(); i++){
				for(var j:Long=0; j<base.size(); j++){
					var x:double = cals.get(i) + base.get(j);
					ne.add(x);
				}
			}
			return multipliedDist(ne, base, days);
		}
	}

	public def makeMarketPortfolioReturnVaR(t:Long, position:HashMap[Market,Double]) :Double {
		val dayFirst = t - t%this.numStepsOneDay;
		var returns:ArrayList[Double];
		if(this.logType){
			//Console.OUT.println("##makeType:log");
			returns = recentMarketPortfolioLogReturnsOneDay(dayFirst, this.sizeDistVaR, position);
		}else{
			//Console.OUT.println("##makeType:normal");
			returns = recentMarketPortfolioNormalReturnsOneDay(dayFirst, this.sizeDistVaR, position);
		}
		var nreturns:ArrayList[Double] = multipliedDistMonte(1, returns, this.numDaysVaR);
		nreturns.sort(); // Sorting of market returns
		var numVaR:Long = Long.operator_as(Math.round( nreturns.size() * ( 1- confInterval )));
		//Console.OUT.print("#1nreturns:");
		//for(var i:Long=0; i<nreturns.size(); i++){
		//	Console.OUT.print( nreturns.get(i) +",");
		//}
		//Console.OUT.println("");
		//Console.OUT.println("#1(1-Interval):"+(1- confInterval ) );
		//Console.OUT.println("#1size:"+ nreturns.size() );
		//Console.OUT.println("#1numVaR0:"+(nreturns.size() * ( 1- confInterval )));
		//Console.OUT.println("#1numVaRceil:"+Long.operator_as(Math.ceil( nreturns.size() * ( 1- confInterval ))) );
		//Console.OUT.println("#1numVaRfloor:"+Long.operator_as(Math.floor( nreturns.size() * ( 1- confInterval ))) );	
		//Console.OUT.println("#1numVaRround:"+Long.operator_as(Math.round( nreturns.size() * ( 1- confInterval ))) );	
		if( numVaR > 0 ){ numVaR = numVaR -1; }
		//Console.OUT.println("value:"+ nreturns(numVaR) );
		return returns(numVaR);
	}

	public def makeMarketPortfolioReturnES(t:Long, position:HashMap[Market,Double]) :Double {
		val dayFirst = t - t%this.numStepsOneDay;
		var returns:ArrayList[Double];
		if(this.logType){
			//Console.OUT.println("##makeType:log");
			returns = recentMarketPortfolioLogReturnsOneDay(dayFirst, this.sizeDistVaR, position);
		}else{
			//Console.OUT.println("##makeType:normal");
			returns = recentMarketPortfolioNormalReturnsOneDay(dayFirst, this.sizeDistVaR, position);
		}
		var nreturns:ArrayList[Double] = multipliedDistMonte(1, returns, this.numDaysVaR);
		nreturns.sort(); // Sorting of market returns
		var out:Double = 0.0;
		var numVaR:Long = Long.operator_as(Math.round( nreturns.size() * ( 1- confInterval )));
		//Console.OUT.println("#2numVaR0:"+(nreturns.size() * ( 1- confInterval )));
		//Console.OUT.println("#2numVaRceil:"+Long.operator_as(Math.ceil( nreturns.size() * ( 1- confInterval ))) );
		//Console.OUT.println("#2numVaRfloor:"+Long.operator_as(Math.floor( nreturns.size() * ( 1- confInterval ))) );	
		//Console.OUT.println("#2numVaRround:"+Long.operator_as(Math.round( nreturns.size() * ( 1- confInterval ))) );
		if( numVaR > 0 ){ numVaR = numVaR -1; }
		for(var i:Long=0; i<=numVaR; i++){
			out = out +nreturns(i);
		}
		out = out/(numVaR+1);

		return out;
	}

	public def makeMarketPortfolioReturnReverseVaR(t:Long, position:HashMap[Market,Double]) :Double {
		val dayFirst = t - t%this.numStepsOneDay;
		var returns:ArrayList[Double];
		if(this.logType){
			//Console.OUT.println("##makeType:log");
			returns = recentMarketPortfolioLogReturnsOneDay(dayFirst, this.sizeDistVaR, position);
		}else{
			//Console.OUT.println("##makeType:normal");
			returns = recentMarketPortfolioNormalReturnsOneDay(dayFirst, this.sizeDistVaR, position);
		}
		var nreturns:ArrayList[Double] = multipliedDistMonte(1, returns, this.numDaysVaR);
		nreturns.sort(); // Sorting of market returns
		nreturns.reverse(); 
		var numVaR:Long = Long.operator_as(Math.round( nreturns.size() * ( 1- confInterval )));
		//Console.OUT.println("#3numVaR0:"+(nreturns.size() * ( 1- confInterval )));
		//Console.OUT.println("#3numVaRceil:"+Long.operator_as(Math.ceil( nreturns.size() * ( 1- confInterval ))) );
		//Console.OUT.println("#3numVaRfloor:"+Long.operator_as(Math.floor( nreturns.size() * ( 1- confInterval ))) );	
		//Console.OUT.println("#3numVaRround:"+Long.operator_as(Math.round( nreturns.size() * ( 1- confInterval ))) );
		if( numVaR > 0 ){ numVaR = numVaR -1; }
		return nreturns(numVaR);
	}

	public def makeMarketPortfolioReturnReverseES(t:Long, position:HashMap[Market,Double]) :Double {
		val dayFirst = t - t%this.numStepsOneDay;
		var returns:ArrayList[Double];
		if(this.logType){
			//Console.OUT.println("##makeType:log");
			returns = recentMarketPortfolioLogReturnsOneDay(dayFirst, this.sizeDistVaR, position);
		}else{
			//Console.OUT.println("##makeType:normal");
			returns = recentMarketPortfolioNormalReturnsOneDay(dayFirst, this.sizeDistVaR, position);
		}
		var nreturns:ArrayList[Double] = multipliedDistMonte(1, returns, this.numDaysVaR);
		nreturns.sort(); // Sorting of market returns
		nreturns.reverse(); 
		var out:Double = 0.0;
		var numVaR:Long = Long.operator_as(Math.round( nreturns.size() * ( 1- confInterval )));
		//Console.OUT.println("#4numVaR0:"+(nreturns.size() * ( 1- confInterval )));
		//Console.OUT.println("#4numVaRceil:"+Long.operator_as(Math.ceil( nreturns.size() * ( 1- confInterval ))) );
		//Console.OUT.println("#4numVaRfloor:"+Long.operator_as(Math.floor( nreturns.size() * ( 1- confInterval ))) );	
		//Console.OUT.println("#4numVaRround:"+Long.operator_as(Math.round( nreturns.size() * ( 1- confInterval ))) );
		if( numVaR > 0 ){ numVaR = numVaR -1; }
		for(var i:Long=0; i<=numVaR; i++){
			out = out +nreturns(i);
		}
		out = out/(numVaR+1);

		return out;
	}


	//今期の時間TimeとtimeSizeを基に，TPORT日毎のノーマルリターンをtimeSize個獲得する.
	public def recentMarketPortfolioNormalReturnsTPORT(t:Long, timeSize:Long, position:HashMap[Market,Double]):ArrayList[Double]{
		return recentMarketPortfolioNormalReturnsSomeDays(t, this.TPORT, timeSize, position);
	}

	//今期の時間TimeとtimeSizeを基に、月次ノーマルリターンをtimeSize個獲得する.
	public def recentMarketPortfolioNormalReturnsOneMonth(t:Long, timeSize:Long, position:HashMap[Market,Double]):ArrayList[Double]{
		return recentMarketPortfolioNormalReturnsSomeDays(t, this.numDaysOneMonth, timeSize, position);
	}

	//今期の時間TimeとtimeSizeを基に、日次ノーマルリターンをtimeSize個獲得する.
	public def recentMarketPortfolioNormalReturnsOneDay(t:Long, timeSize:Long, position:HashMap[Market,Double]):ArrayList[Double]{
		return recentMarketPortfolioNormalReturnsSomeDays(t, 1, timeSize, position);
	}


	//今期の時間TimeとSomeDays,timeSizeを基に、SomeDays日毎のノーマルリターンをtimeSize個獲得する.
	public def recentMarketPortfolioNormalReturnsSomeDays(t:Long, SomeDays:Long, timeSize:Long, position:HashMap[Market,Double]):ArrayList[Double]{
		val T = t - t%(SomeDays*this.numStepsOneDay);
		var out:ArrayList[Double] = new ArrayList[Double]();
		for(var i:Long = 0; i < timeSize; i++){
			val r = ( presentMarketPortfolioPriceSomeDays( T +(i+1-timeSize)*SomeDays*this.numStepsOneDay ,SomeDays, position) 
						- presentMarketPortfolioPriceSomeDays( T +(i-timeSize)*SomeDays*this.numStepsOneDay ,SomeDays, position) )
						/ presentMarketPortfolioPriceSomeDays( T +(i-timeSize)*SomeDays*this.numStepsOneDay ,SomeDays, position);
			out.add(r);
		}
		return out;
	}


	//今期の時間TimeとtimeSizeを基に，TPORT日毎の対数リターンをtimeSize個獲得する.
	public def recentMarketPortfolioLogReturnsTPORT(t:Long, timeSize:Long, position:HashMap[Market,Double]):ArrayList[Double]{
		return recentMarketPortfolioLogReturnsSomeDays(t, this.TPORT, timeSize, position);
	}

	//今期の時間TimeとtimeSizeを基に、月次対数リターンをtimeSize個獲得する.
	public def recentMarketPortfolioLogReturnsOneMonth(t:Long, timeSize:Long, position:HashMap[Market,Double]):ArrayList[Double]{
		return recentMarketPortfolioLogReturnsSomeDays(t, this.numDaysOneMonth, timeSize, position);
	}

	//今期の時間TimeとtimeSizeを基に、日次対数リターンをtimeSize個獲得する.
	public def recentMarketPortfolioLogReturnsOneDay(t:Long, timeSize:Long, position:HashMap[Market,Double]):ArrayList[Double]{
		return recentMarketPortfolioLogReturnsSomeDays(t, 1, timeSize, position);
	}


	//今期の時間TimeとSomeDays,timeSizeを基に、SomeDays日毎の対数リターンをtimeSize個獲得する.
	public def recentMarketPortfolioLogReturnsSomeDays(t:Long, SomeDays:Long, timeSize:Long, position:HashMap[Market,Double]):ArrayList[Double]{
		val T = t - t%(SomeDays*this.numStepsOneDay);
		var out:ArrayList[Double] = new ArrayList[Double]();
		for(var i:Long = 0; i < timeSize; i++){
			val r = Math.log(	   presentMarketPortfolioPriceSomeDays( T +(i+1-timeSize)*SomeDays*this.numStepsOneDay ,SomeDays, position)
						 / presentMarketPortfolioPriceSomeDays( T +(i-timeSize)*SomeDays*this.numStepsOneDay ,SomeDays, position)
					);
			out.add(r);
		}
		return out;
	}


	//TPORTはじめの時点でのポジションの市場価値を与える.
	public def presentMarketPortfolioPriceTPORT(t:Long, position:HashMap[Market,Double]): Double {
		return presentMarketPortfolioPriceSomeDays(t,this.TPORT, position);
	}

	//月はじめの時点でのポジションの市場価値を与える.
	public def presentMarketPortfolioPriceOneMonth(t:Long, position:HashMap[Market,Double]): Double {
		return presentMarketPortfolioPriceSomeDays(t,this.numDaysOneMonth, position);
	}


	//その日のはじめの時点でのポジションの市場価値を与える.
	public def presentMarketPortfolioPriceOneDay(t:Long, position:HashMap[Market,Double]): Double {
		return presentMarketPortfolioPriceSomeDays(t,1, position);
	}


	//今期の時間TimeとSomeDaysを基に、SomeDays開始時点でのポジションの市場価値を与える. 
	public def presentMarketPortfolioPriceSomeDays(t:Long,SomeDays:Long, position:HashMap[Market,Double]): Double {
		val T = t - t%(SomeDays*this.numStepsOneDay);
		var out:Double = 0.0;
		for(market in accessibleMarkets){
			out = out + presentMarketPricesStep(T).get(market)*position.get(market);
		}
		return out;
	}

	public def presentMarketPortfolioPriceStep(t:Long, position:HashMap[Market,Double]): Double {
		val T = t;
		var out:Double = 0.0;
		for(market in accessibleMarkets){
			out = out + presentMarketPricesStep(T).get(market)*position.get(market);
		}
		return out;
	}


	/*public var testMarketPrices:ArrayList[HashMap[Market,Double] ];
	public def presentMarketPrices(T:Long):HashMap[Market,Double]{
		return this.testMarketPrices(T);
	}*/

	public static def main(args:Rail[String]) {
/*		val markets = new ArrayList[Market]();
		val markets2 = new ArrayList[Market]();
		val m1 = new Market();
		m1.setName("m1");
		val m2 = new Market();
		m2.setName("m2");
		val m3 = new Market();
		m3.setName("m3");
		val agent = new FCNBaselMarkowitzPortfolioAgent();
		markets.add(m1);
		markets.add(m2);
		markets2.add(m1);
		markets2.add(m2);
		markets2.add(m3);
		agent.accessibleMarkets = markets;
		agent.allMarkets = markets2;
		agent.testMarketPrices = new ArrayList[HashMap[Market,Double] ](101);

		for(T in 0..100){
			agent.testMarketPrices(T) = new HashMap[Market,Double]();
			agent.testMarketPrices(T).put(m1,(T+1 as Double));
			agent.T).put(m1,2*(T+1 as Double));
		}

		var position:HashMap[Market,Double] = new HashMap[Market,Double]();

		position.put(m1,100.0);
		position.put(m2,100.0);
*/
		/*for(T in 0..100){
			Console.OUT.println("*value["+T+"]="+ agent.presentMarketPortfolioPrice(T,position) );
		}*/

/*		recentMarketPortfolioReturnTPORT:ArrayList[Double] = agent.recentMarketPortfolioReturnTPORT(100,10, 10, position);

		for(step in 0..(recentMarketPortfolioReturnTPORT.size()-1)){
			Console.OUT.println("*stepX["+step+"]="+ recentMarketPortfolioReturnTPORT(step) );
			Console.OUT.println("*stepY["+step+"]="+ (agent.presentMarketPortfolioPrice((step+1)*10,position)/agent.presentMarketPortfolioPrice(step*10,position)  ) );
		}*/
		/*
		var x:Rail[Long] = new Rail[Long](3);
		x(0) = 3;
		x(1) =-2;
		x(2) = 0;  
		test2(x);
		*//*
		var x:Rail[Double] = new Rail[Double](3);
		var y:Rail[Double] = new Rail[Double](3);
		x(0) = 2.0;
		x(1) = 2.0;
		x(2) = 2.0; 
		y(0) = 12.0;
		y(1) = 12.0;
		y(2) = 12.0; 
		var hoge:ArrayList[Rail[Double]] = lineSegment(x,y,1.0);
		for(var i:Long=0; i<hoge.size(); i++){
			Console.OUT.println("*i="+i);
			Matrix.dump(hoge.get(i));
		}*/
/*
		val markets = new ArrayList[Market]();
		val markets2 = new ArrayList[Market]();
		val m1 = new Market(-1);
		m1.env = new Env();
		m1.setName("m1");
		val m2 = new Market(-1);
		m2.setName("m2");
		m2.env = new Env();
		val m3 = new Market(-1);
		m3.setName("m3");
		m3.env = new Env();
		val agent = new FCNBaselMarkowitzPortfolioAgent();
		m1.env.agents.add(agent);
		m2.env.agents.add(agent);
		m3.env.agents.add(agent);
		m1.setId(0);
		m2.setId(1);
		m3.setId(2);
		markets.add(m1);
		markets.add(m2);
		markets2.add(m1);
		markets2.add(m2);
		markets2.add(m3);
		agent.accessibleMarkets = markets;
		agent.allMarkets = markets2;
		var x2:Rail[Long] = new Rail[Long](2);
		val orderMarket:ArrayList[Market] = agent.marketOrder();
		x2(0) = 3;
		x2(1) =-2;
		var x3:Rail[Long] = new Rail[Long](2);
		x3(0) =-2;
		x3(1) =3;
		//x3(0) = 3;
		//x3(1) =-2;
		Console.OUT.println("*result:"+ FCNBaselMarkowitzPortfolioAgent.eqcheck(x2,x3) );

		var set:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]](0);

		set = FCNBaselMarkowitzPortfolioAgent.addArrayList(set, FCNMarkowitzPortfolioAgent.translation3(FCNMarkowitzPortfolioAgent.translation9(x2, orderMarket), orderMarket ),orderMarket );
		set = FCNBaselMarkowitzPortfolioAgent.addArrayList(set, FCNMarkowitzPortfolioAgent.translation3(FCNMarkowitzPortfolioAgent.translation9(x3, orderMarket), orderMarket ),orderMarket );

		for(var i:Long=0; i<set.size(); i++){
			Console.OUT.println("**i="+i);
			FCNMarkowitzPortfolioAgent.dump(set.get(i),orderMarket);
		}
*/
	/*
		val markets = new ArrayList[Market]();
		val markets2 = new ArrayList[Market]();
		val m1 = new Market(-1);
		m1.env = new Env();
		m1.setName("m1");
		val m2 = new Market(-1);
		m2.setName("m2");
		m2.env = new Env();
		val m3 = new Market(-1);
		m3.setName("m3");
		m3.env = new Env();
		val agent = new FCNBaselMarkowitzPortfolioAgent();
		m1.env.agents.add(agent);
		m2.env.agents.add(agent);
		m3.env.agents.add(agent);
		m1.setId(0);
		m2.setId(1);
		m3.setId(2);
		markets.add(m1);
		markets.add(m2);
		markets2.add(m1);
		markets2.add(m2);
		markets2.add(m3);
		agent.accessibleMarkets = markets;
		agent.allMarkets = markets2;
		Console.OUT.println("*marketOrder");
		var x2:Rail[Long] = new Rail[Long](2);
		x2(0) = 3;
		x2(1) =-2;
		var orderMarket:ArrayList[Market] = agent.accessibleMarkets as ArrayList[Market];
		for(var i:Long = 0; i<orderMarket.size(); i++){
			Console.OUT.println(i+":"+orderMarket.get(i).name+","+orderMarket.get(i).id);
		}
		var x:HashMap[Market,Long] = FCNMarkowitzPortfolioAgent.translation3(FCNMarkowitzPortfolioAgent.translation9(x2, orderMarket), orderMarket );
		Console.OUT.println("*x");
		FCNMarkowitzPortfolioAgent.dump(x,orderMarket);
		var hoge:ArrayList[HashMap[Market,Long]] = FCNBaselMarkowitzPortfolioAgent.getLongCandidates2(x2, orderMarket);
		var i:Long =0;
		Console.OUT.println("*before:");
		for(y in hoge){
			Console.OUT.println("**i="+i);
			FCNMarkowitzPortfolioAgent.dump(y,orderMarket);
			i++;
		}
		Console.OUT.println("*x");
		FCNMarkowitzPortfolioAgent.dump(x,orderMarket);

		var neighbors:ArrayList[HashMap[Market,Long]] = FCNBaselMarkowitzPortfolioAgent.removeArrayList( hoge, x, orderMarket ) ;
		i=0;
		Console.OUT.println("*after:");
		for(y in neighbors){
			Console.OUT.println("**i="+i);
			FCNMarkowitzPortfolioAgent.dump(y,orderMarket);
			i++;
		}
*/
/*
		//var x:Rail[Long] = new Rail[Long](2);
		var x:Rail[Long] = new Rail[Long](3);
		for(var t:Long = 0; t<10; t++){
			test3(x,t);
		}
*/

		val n = Long.parse(args(0));


		val markets = new ArrayList[Market]();
		val markets2 = new ArrayList[Market]();
		val m1 = new Market(-1);
		m1.env = new Env();
		m1.setName("m1");
		val m2 = new Market(-1);
		m2.setName("m2");
		m2.env = new Env();
/*		val m3 = new Market(-1);
		m3.setName("m3");
		m3.env = new Env();
		val m4 = new Market(-1);
		m4.setName("m4");
		m4.env = new Env();
		val m5 = new Market(-1);
		m5.setName("m5");
		m5.env = new Env();
*/		val agent = new FCNBaselMarkowitzPortfolioAgent();
		m1.env.agents.add(agent);
		m2.env.agents.add(agent);
/*		m3.env.agents.add(agent);
		m4.env.agents.add(agent);
		m5.env.agents.add(agent);
*/		m1.setId(0);
		m2.setId(1);
/*		m3.setId(2);
		m4.setId(3);
		m5.setId(4);
*/		markets2.add(m1);
		markets2.add(m2);
/*		markets2.add(m3);
		markets2.add(m4);
		markets2.add(m5);
*/
		for(var i:Long = 0; i<n; i++){		
			markets.add(markets2.get(i));
		}

		agent.accessibleMarkets = markets;
		agent.allMarkets = markets2;
		agent.distanceType = args(1);
		//agent.riskType = args(2);
		var x:Rail[Long] = new Rail[Long](n);
		val orderMarket:ArrayList[Market] = agent.marketOrder();
		for(var t:Long = 0; t<=5; t++){
			var neighbors:ArrayList[HashMap[Market,Long]] = new ArrayList[HashMap[Market,Long]]();

			if(agent.distanceType.equals("Manhattan")){
				neighbors = FCNBaselMarkowitzPortfolioAgent.getManhattanDistanceNeighbor(x, orderMarket,t );
			}else if(agent.distanceType.equals("Chebyshev")){
				neighbors = FCNBaselMarkowitzPortfolioAgent.getChebyshevDistanceNeighbor(x, orderMarket,t );
			}else{
				neighbors = FCNBaselMarkowitzPortfolioAgent.getManhattanDistanceNeighbor(x, orderMarket,t );
			}
			var i:Long =0;
			Console.OUT.println("***d="+t+": "+neighbors.size());
			/*for(y in neighbors){
				//Console.OUT.println("**i="+i);
				FCNMarkowitzPortfolioAgent.dump(y,orderMarket);
				i++;
			}*/
		}
		Console.OUT.println("hogeEnd");


	}
	public static def register(sim:Simulator):void {
		val className = "FCNBaselMarkowitzPortfolioAgent";
		sim.addAgentInitializer(className, (range:LongRange, json:JSON.Value, container:Settable[Long, Agent]) => {
			for (i in range) {
				container(i) = createFCNBaselMarkowitzPortfolioAgent(json, sim);
			}
		});
	}

	public static def createFCNBaselMarkowitzPortfolioAgent(json:JSON.Value, sim:Simulator):FCNBaselMarkowitzPortfolioAgent {
		val jsonrandom = new JSONRandom(sim.getRandom());
		return new FCNBaselMarkowitzPortfolioAgent().setupFCNBaselMarkowitzPortfolioAgent(json, jsonrandom, sim);
	}

	public def setupFCNBaselMarkowitzPortfolioAgent(json:JSON.Value, random:JSONRandom, sim:Simulator):FCNBaselMarkowitzPortfolioAgent {
		setupAgent(json, random, sim);
		this.fundamentalWeight = random.nextRandom(json("fundamentalWeight"));
		this.chartWeight = random.nextRandom(json("chartWeight"));	
		this.noiseWeight = random.nextRandom(json("noiseWeight"));
		this.noiseScale = random.nextRandom(json("noiseScale"));
		this.timeWindowSize = random.nextRandom(json("timeWindowSize")) as Long;
		//val fcRatio = (1.0 + this.fundamentalWeight) / (1.0 + this.chartWeight);
		this.fundamentalMeanReversionTime = random.nextRandom(json("fundamentalMeanReversionTime")) as Long;
		this.shortSellingAbility = json("shortSellingAbility").toBoolean();
		this.leverageRate = json("leverageRate").toDouble();
		assert this.fundamentalWeight >= 0.0 : "fundamentalWeight >= 0.0";
		assert this.chartWeight >= 0.0 : "chartWeight >= 0.0";
		assert this.noiseWeight >= 0.0 : "noiseWeight >= 0.0";
		this.b= random.nextRandom(json("b"));
		this.TPORT = json("tport").toLong();
		this.lastUpdated = 0; //正しい？
		//assert json("accessibleMarkets").size() == 2 : "FCNAgents suppose only one Market";
		var markets:ArrayList[Market] = new ArrayList[Market]();
		for (m in 0..(json("accessibleMarkets").size()-1)) {
			val name = json("accessibleMarkets")(m).toString();
			markets.add((sim.GLOBAL(name) as List[Market])(0));
		}
		this.allMarkets = markets as List[Market];
		this.accessibleMarkets = markets as List[Market]; 
		for (m in this.accessibleMarkets) {
			this.setMarketAccessible(m);
			this.setAssetVolume(m, random.nextRandom(json("assetVolume")) as Long);
		}
		this.setCashAmount(random.nextRandom(json("cashAmount")));
		//Console.OUT.println("# a0");
		if(json.has("logType")){
			//Console.OUT.println("# a2");
			this.logType = json("logType").toBoolean();
		}
		this.session0iterationDays = sim.CONFIG("simulation")("sessions")(0)("iterationDays").toLong();
		this.numStepsOneDay  = sim.CONFIG("numStepsOneDay").toLong();
		this.numDaysOneMonth = sim.CONFIG("numDaysOneMonth").toLong();
		this.covarfundamentalWeight = sim.CONFIG("covarfundamentalWeight").toDouble();
		this.orderMarket = this.marketOrder();

		this.distanceType = json("distanceType").toString();
		this.riskType = json("riskType").toString();
		this.confInterval = json("confInterval").toDouble();	//VaR,ES計算時に用いる信頼水準のパーセンテージx( x ∈ (0.0, 1.0) )  nomura2014,pdfによれば，VaRのときは0.99でESのときは0.975.
		this.confCoEfficient = Gaussian2.confidence(this.confInterval); //信頼係数
		//ただバーゼル2.5だとストレスVaRとか入れてたりするので，更にややこしくて美しくない.
		this.numDaysVaR = json("numDaysVaR").toLong();
		this.sizeDistVaR = json("sizeDistVaR").toLong();	//VaR,ESの計算をするときのリターンのサンプル（毎日のリターン）の数(サンプルはTPORT毎の過去の時系列リターン)．
		this.coMarketRisk = json("coMarketRisk").toDouble();	//ウェブで見つけたデロイトトーマツの資料によれば，12.5となっていた．
		this.threshold = json("threshold").toDouble();	//バーゼル規制違反の有無判断に用いる自己資本比率の閾値x( x ∈ (0.0, 1.0) ) 国際統一基準は0.08、国内基準は0.04
		this.isLimitVariable = json("isLimitVariable").toBoolean(); //If IsLimitVariable is true, we use limitOrderPriceRate. Otherwise, we use limitOrderPrice.
		if(this.isLimitVariable){
			this.underLimitPriceRate = json("underLimitPriceRate").toDouble();
			this.overLimitPriceRate = json("overLimitPriceRate").toDouble();
		}else{
			this.underLimitPrice = json("underLimitPrice").toDouble();
			this.overLimitPrice = json("overLimitPrice").toDouble();
		}

		if (DEBUG == -3) {
			Console.OUT.println("##\tfundamentalWeight:"+ this.fundamentalWeight );
			Console.OUT.println("##\tchartWeight:"+ this.chartWeight );
			Console.OUT.println("##\tnoiseWeight:"+ this.noiseWeight );
			Console.OUT.println("##\tnoiseScale:"+ this.noiseScale );
			Console.OUT.println("##\ttimeWindowSize:"+ this.timeWindowSize );
			Console.OUT.println("##\tfundamentalMeanReversionTime:"+ this.fundamentalMeanReversionTime );
			Console.OUT.println("##\tb:"+ this.b );
			Console.OUT.println("##\tassetsVolumes:");
			Console.OUT.print("#");
			FCNBaselMarkowitzCI2002Main.dump(this.assetsVolumes, this.orderMarket  );
			Console.OUT.println("##\tcashAmount:"+ this.cashAmount );
		}
		return this;
	}



}

