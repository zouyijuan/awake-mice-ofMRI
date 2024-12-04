///以下参数需定义
long  offWaittime = 45000L;//ms dummyscan+baseline
long  blueTime = 15000L;//ms
int  blueFrequency = 10;//Hz
float  blueDutycycle = 0.05;
long  blueOfftime = 30000L;//ms
int  blockNumber = 100;
int triggerNumber = 4;

const int trigger = 3; // 连接trigger
const int blue = 13; // 连接蓝光

int blueNumberPerBlock = blueTime/(1000/blueFrequency);
int dutycycleOn = 1000/blueFrequency*blueDutycycle;
int dutycycleOff = 1000/blueFrequency*(1-blueDutycycle);

int a = 0;
int b = 0;
int c = 0;
int triggerState = 1; 
void setup() {

pinMode(blue, OUTPUT);
pinMode(trigger, INPUT);
}
void loop(){

triggerState = digitalRead(trigger);

if (triggerState == LOW) {
triggerState=1;
a++;
  delay(500);
}
else {
digitalWrite(blue, LOW);}
if (a==triggerNumber) {
  if(b==0){
  digitalWrite(blue, LOW);
  delay(offWaittime);
  b++;
  }
  else{
    while (c<blockNumber){    // block cishu 
      
 for (int i=0;i<blueNumberPerBlock;i=i+1)   // cishu per block on
  {  
  digitalWrite(blue, HIGH);
  delay(dutycycleOn);  
  digitalWrite(blue, LOW);   
  delay(dutycycleOff);
  }  //Blue on

  
  digitalWrite(blue, LOW); 
  delay(blueOfftime);  //off
  
  c++;

}
  c = 0;
 
}
}
}
