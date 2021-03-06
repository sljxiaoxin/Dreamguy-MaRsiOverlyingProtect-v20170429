//+------------------------------------------------------------------+
//|                              
//|  1、marti前先对冲，只能对冲一次，对冲的时候原单和对冲单，哪个先达目标点位则平仓，随后需要在字典里做key调换。
//|  2、对冲关闭后，开始看情况marti，marti后不能再对冲。
//|                                                      
//|                                              
//+------------------------------------------------------------------+
#property copyright "xiaoxin003"
#property link      "yangjx009@139.com"
#property version   "1.00"
#property strict

#include <Arrays\ArrayInt.mqh>
#include "dictionary.mqh" //keyvalue数据字典类
#include "trademgr.mqh"   //交易工具类
#include "citems.mqh"     //交易组item
#include "martimgr.mqh"   //马丁管理类
#include "mamgr.mqh"      //均线数值管理类
#include "profitmgr.mqh"      //均线数值管理类

extern int       MagicNumber     = 20170429;
extern double    Lots            = 0.2;
extern double    TPinMoney       = 20;          //Net TP (money)
extern int       MaxGroupNum     = 5;
extern int       MaxMartiNum     = 2;
extern double    Mutilplier      = 1;   //马丁加仓倍数
extern int       GridSize        = 50;

int       NumberOfTries   = 10,
          Slippage        = 5;
datetime  CheckTime;
double    Pip;
CTradeMgr *objCTradeMgr;  //订单管理类
CMartiMgr *objCMartiMgr;  //马丁管理类
CDictionary *objDict = NULL;     //订单数据字典类
CProfitMgr *objProfitMgr; //利润和仓位管理类
int tmp = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//---
   Print("begin");
   if(Digits==2 || Digits==4) Pip = Point;
   else if(Digits==3 || Digits==5) Pip = 10*Point;
   else if(Digits==6) Pip = 100*Point;
   if(objDict == NULL){
      objDict = new CDictionary();
      objCTradeMgr = new CTradeMgr(MagicNumber, Pip, NumberOfTries, Slippage);
      objCMartiMgr = new CMartiMgr(objCTradeMgr, objDict);
      objProfitMgr = new CProfitMgr(objCTradeMgr,objDict);
   }
   objCMartiMgr.Init(GridSize, MaxMartiNum, Mutilplier);
   objProfitMgr.Init(TPinMoney);
//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Print("deinit");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
     subPrintDetails();
     if(CheckTime==iTime(NULL,0,0)){
         return;
     } else {
         CheckTime = iTime(NULL,0,0);
         /*
            每次新柱的开始：
            1、获取计算均线所需数据，计算常用均线位置值。
            2、遍历keyValue数据字典，分析该做何操作。
            3、开单检测buy / sell。
            4、
         */
         
         CMaMgr::Init();
         //objCMartiMgr.Init(GridSize,MaxMartiNum,Mutilplier);
         objCMartiMgr.CheckAllMarti();
         objProfitMgr.EachColumnDo();
         objProfitMgr.CheckTakeprofit();
         objProfitMgr.CheckOpenHedg();
         dealRSI();
        
         
     }
 }
  
//根据rsi和均线开单处理
string RSIPosition = "";
datetime CrossTime;
void dealRSI(){
   int candleCrossNums;
   double Rsi3_one = iRSI(NULL,0,3,PRICE_CLOSE,1);
   double Rsi3_two = iRSI(NULL,0,3,PRICE_CLOSE,2);
   if(RSIPosition ==""){
      if(Rsi3_one >50){
         RSIPosition = "above";
      }else{
         RSIPosition = "below";
      }
      
      CrossTime = iTime(NULL,0,0);
   }else if(RSIPosition == "above"){
      if(Rsi3_two>50 && Rsi3_one<=50){
         //Print("DOWN!");
         RSIPosition = "below";
         candleCrossNums = (CheckTime-CrossTime)/60/Period();
        // if((TimeCurrent()-prev_order_time_buy)/60<intZhuziNums*Period()){
         //Print("RSIPosition:",RSIPosition,"| candleCrossNums:",candleCrossNums);
         CrossTime = iTime(NULL,0,0);
         RSICrossSell(candleCrossNums);
      }
   }else if(RSIPosition == "below"){
      if(Rsi3_two<=50 && Rsi3_one>50){
        // Print("UP!");
         RSIPosition = "above";
         candleCrossNums = (CheckTime-CrossTime)/60/Period();
         //Print("RSIPosition:",RSIPosition,"| candleCrossNums:",candleCrossNums);
         CrossTime = iTime(NULL,0,0);
         RSICrossBuy(candleCrossNums);
      }
   }
}

void RSICrossBuy(int candleNum){
   //Print("RSICrossBuy objDict.total is :",objDict.Total());
   if(candleNum>6 || objDict.Total()>=MaxGroupNum){
      return ;
   }
   if(objDict.Total() >0){
      CItems* currItem = objDict.GetLastNode();
      if(currItem.Hedg == 0 && currItem.GetType()== "rsi"){
         return;
      }
      currItem = NULL;
   }
   //Print("RSICrossBuy s_ma10----",CMaMgr::s_ma10);
   //Print("RSICrossBuy s_ma10Overlying----",CMaMgr::s_ma10Overlying);
   //Print("RSICrossBuy s_ma120----",CMaMgr::s_ma120);
   //Print("RSICrossBuy s_ma120Overlying----",CMaMgr::s_ma120Overlying);
   if(CMaMgr::s_ma10 > CMaMgr::s_ma10Overlying && CMaMgr::s_ma10Overlying > CMaMgr::s_ma120 && CMaMgr::s_ma120>CMaMgr::s_ma120Overlying){
      //Print("MA BUY!!!");
      int t = 0;
      t = objCTradeMgr.Buy(Lots, 0, 0, "rsi");
      if(t != 0){
         objDict.AddObject(t, new CItems(t, "rsi", TPinMoney));
      }
   }
   
}
void RSICrossSell(int candleNum){
   //Print("RSICrossSell objDict.total is :",objDict.Total());
   if(candleNum>6 || objDict.Total()>=MaxGroupNum){
      return ;
   }
   if(objDict.Total() >0){
      CItems* currItem = objDict.GetLastNode();
      if(currItem.Hedg == 0 && currItem.GetType()== "rsi"){
         return;
      }
      currItem = NULL;
   }
   //Print("RSICrossSell s_ma10----",CMaMgr::s_ma10);
  // Print("RSICrossSell s_ma10Overlying----",CMaMgr::s_ma10Overlying);
   //Print("RSICrossSell s_ma120----",CMaMgr::s_ma120);
   //Print("RSICrossSell s_ma120Overlying----",CMaMgr::s_ma120Overlying);
   if(CMaMgr::s_ma10 < CMaMgr::s_ma10Overlying && CMaMgr::s_ma10Overlying < CMaMgr::s_ma120 && CMaMgr::s_ma120<CMaMgr::s_ma120Overlying){
      int t = 0;
      t = objCTradeMgr.Sell(Lots, 0, 0, "rsi");
      if(t != 0){
         objDict.AddObject(t, new CItems(t, "rsi", TPinMoney));
      }
   }
}


void dealCross(){

}
void dealFirst(){

}

void subPrintDetails()
{
   string sComment   = "";
   string sp         = "----------------------------------------\n";
   string NL         = "\n";

   sComment = sp;
   sComment = sComment + "Net = " + TotalNetProfit() + NL; 
   sComment = sComment + "GroupNum = " + objDict.Total() + NL; 
   sComment = sComment + sp;
   sComment = sComment + "Lots=" + DoubleToStr(Lots,2) + NL;
   CItems* currItem = objDict.GetFirstNode();
   for(int i = 1; (currItem != NULL && CheckPointer(currItem)!=POINTER_INVALID); i++)
   {
      sComment = sComment + sp;
      sComment = sComment + currItem.GetTicket()+ ":" + currItem.Hedg + " | ";
      for(int i=0;i<currItem.Marti.Total();i++){
         sComment = sComment + currItem.Marti.At(i) + ",";
      }
      sComment = sComment + NL;
      if(objDict.Total() >0){
         currItem = objDict.GetNextNode();
      }else{
         currItem = NULL;
      }
   }
   
  
   Comment(sComment);
}

double TotalNetProfit()
{
     double op = 0;
     for(int cnt=0;cnt<OrdersTotal();cnt++)
      {
         OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
         if(OrderType()<=OP_SELL &&
            OrderSymbol()==Symbol() &&
            OrderMagicNumber()==MagicNumber)
         {
            op = op + OrderProfit();
         }         
      }
      return op;
}


