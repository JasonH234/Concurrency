/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20001
// ASSIGNMENT 1
// TITLE: "LED Ant Defender Game"
// DILLON KEITH DIEP & JASON HACIEPIRI
//
/////////////////////////////////////////////////////////////////////////////////////////

//GAME END = -1;

#include <stdio.h>
#include <platform.h>

out port cled0 = PORT_CLOCKLED_0;
out port cled1 = PORT_CLOCKLED_1;
out port cled2 = PORT_CLOCKLED_2;
out port cled3 = PORT_CLOCKLED_3;
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
in port buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;

/////////////////////////////////////////////////////////////////////////////////////////
//
// Helper Functions provided for you
//
/////////////////////////////////////////////////////////////////////////////////////////

//DISPLAYS an LED pattern in one quadrant of the clock LEDs
int showLED(out port p, chanend fromVisualiser)
{
    int lightUpPattern = 0;

    while (lightUpPattern != -1)
    {
        fromVisualiser :> lightUpPattern;   //read LED pattern from visualiser process
        p <: lightUpPattern;                //send pattern to LEDs
    }
    p <: 0;
    printf("Terminated showLED\n");
    return 0;
}

//PROCESS TO COORDINATE DISPLAY of LED Ants
void visualiser(chanend fromUserAnt, chanend fromAttackerAnt, chanend toQuadrant0, chanend toQuadrant1, chanend toQuadrant2, chanend toQuadrant3)
{
    int userAntToDisplay = 11;
    int attackerAntToDisplay = 5;

    int i, j;
    cledG <: 1;
    while (userAntToDisplay != -1)
    {
        select
        {
            case fromUserAnt :> userAntToDisplay:
                break;
            case fromAttackerAnt :> attackerAntToDisplay:
                break;
        }
        j = 16<<(userAntToDisplay%3);
        i = 16<<(attackerAntToDisplay%3);
        toQuadrant0 <: (j*(userAntToDisplay/3==0)) + (i*(attackerAntToDisplay/3==0)) ; /*0b01110000;*/
        toQuadrant1 <: (j*(userAntToDisplay/3==1)) + (i*(attackerAntToDisplay/3==1)) ;
        toQuadrant2 <: (j*(userAntToDisplay/3==2)) + (i*(attackerAntToDisplay/3==2)) ;
        toQuadrant3 <: (j*(userAntToDisplay/3==3)) + (i*(attackerAntToDisplay/3==3)) ;
    }
    //Ending
    if (userAntToDisplay == -1)
    {
        toQuadrant0 <: -1;
        toQuadrant1 <: -1;
        toQuadrant2 <: -1;
        toQuadrant3 <: -1;
        printf("Terminated visualiser\n");
        return;
    }
}

//PLAYS a short sound (pls use with caution and consideration to other students in the labs!)
void playSound(int wavelength, out port speaker)
{
    timer tmr;
    int t, isOn = 1;
    tmr :> t;
    for (int i=0; i<2; i++)
    {
        isOn = !isOn;
        t += wavelength;
        tmr when timerafter(t) :> void;
        speaker <: isOn;
    }
}

//WAIT function
void waitMoment(int waitAmount)
{
    timer tmr;
    uint waitTime;
    tmr :> waitTime;
    waitTime += waitAmount;
    tmr when timerafter(waitTime) :> void;
}

//READ BUTTONS and send to userAnt
void buttonListener(in port b, out port spkr, chanend toUserAnt) {
  int r;
  while (1) {
    select
    {
        case toUserAnt :> r:
                printf("Terminated buttonListener, r == %d\n", r);
                return;
                break;
        case b when pinsneq(15) :> r:   // check if some buttons are pressed
            printf("r == %d\n", r);
            playSound(2000000,spkr);   // play sound
            toUserAnt <: r;            // send button pattern to userAnt
            waitMoment(100000);
            break;
    }
  }
}

//BoundsCheck
int checkBounds(int pos)
{
    if(pos < 0)
    {
        return 11;
    }
    else if(pos > 11)
    {
        return 0;
    }
    else
    {
        return pos;
    }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// MOST RELEVANT PART OF CODE TO EXPAND FOR YOU
//
/////////////////////////////////////////////////////////////////////////////////////////

//DEFENDER PROCESS... The defender is controlled by this process userAnt,
//                    which has channels to a buttonListener, visualiser and controller

int attemptMove(int attemptedAntPosition, int userAntPosition, chanend toController, chanend toVisualiser){
    int moveForbidden = 0;                      //the verdict of the controller if move is allowed, terminate if -1

    select{
        //if number already on channel, then put in move forbidden
        case toController :> moveForbidden:
            break;
        default:
            //Send attempted position to controller
            toController <: attemptedAntPosition;
            //wait to receive 0 for move allowed, or 1 for move forbidden.
            toController :> moveForbidden;
            break;
    }

    if(moveForbidden == 0)
    {
        userAntPosition = attemptedAntPosition;
        //Update visual display with new ant position
        toVisualiser <: userAntPosition;
        printf("Defender moved to %d\n", userAntPosition);
    }
    else
    {
        //move forbidden.
        printf("Move to %d not allowed\n", userAntPosition);
        //end game signal
        if(moveForbidden == -1){
            userAntPosition = -1;
        }
    }
    return userAntPosition;
}

void pauseDefender(chanend fromButtons, chanend toController){
    //Resetting buttonInput for pause toggle functionality
    int buttonInput = 0;
    //Send pause signal (-1) to controller
    toController <: -1;
    //Await continuation
    while (buttonInput != 13)
        fromButtons :> buttonInput;
    //Initiate unpause condition
    toController <: -2;
}

void terminateDefender(chanend fromButtons, chanend toVisualiser){
    toVisualiser <: -1;
    //Select statement to end buttonListener regardless whether a button is held down or not.
    select
    {
        case fromButtons :> int i:
            break;
        default:
            break;
    }
    fromButtons <: -1;
}

int buttonPressed(int buttonInput, int userAntPosition, chanend fromButtons, chanend toController, chanend toVisualiser){
    int attemptedAntPosition;              //the next attempted defender position after considering button

    switch(buttonInput){
        case 7:     //anti clockwise move 1
            attemptedAntPosition = checkBounds(userAntPosition -1);
            userAntPosition = attemptMove(attemptedAntPosition, userAntPosition, toController, toVisualiser);
            break;
        case 11:    //restart, so reset user ant position and send restart signal to controller
            userAntPosition = 11;
            toVisualiser <: userAntPosition;
            toController <: -3;
            break;
        case 13:    //pause
            pauseDefender(fromButtons, toController);
            break;
        case 14:    //clockwise move 1
            attemptedAntPosition = checkBounds(userAntPosition +1);
            userAntPosition = attemptMove(attemptedAntPosition, userAntPosition, toController, toVisualiser);
            break;
    }
    return userAntPosition;
}

void userAnt(chanend fromButtons, chanend toVisualiser, chanend toController)
{
    int userAntPosition = 11;                   //the current defender position
    int buttonInput;                            //the input pattern from the buttonListener
    int controllerSignal;
    toVisualiser <: userAntPosition;            //show initial position

    fromButtons :> buttonInput;                 //Initial button to start

    while (1)
    {
        select
        {
            case toController :> controllerSignal:
                userAntPosition = -1;
                break;
            case fromButtons :> buttonInput:
                userAntPosition = buttonPressed(buttonInput, userAntPosition, fromButtons, toController, toVisualiser);
                break;
        }
        if(userAntPosition == -1){
            terminateDefender(fromButtons, toVisualiser);
            printf("Terminated defender\n");
            return;
        }
    }
}

//ATTACKER PROCESS... The attacker is controlled by this process attackerAnt,
// which has channels to the visualiser and controller
void attackerAnt(chanend toVisualiser, chanend toController)
{
    int moveCounter = 0;                        //moves of attacker so far
    int attackerAntPosition = 5;                //the current attacker position
    int attemptedAntPosition;                   //the next attempted position after considering move direction
    int currentDirection = 1;                   //the current direction the attacker is moving
    int moveForbidden = 0;                      //the verdict of the controller if move is allowed
    toVisualiser <: attackerAntPosition;        //show initial position
    int speed = 10000000;

    while (1)
    {
        //invert current direction when move counter is divisable by 31, 37 and 47
        if(moveCounter%31==0 || moveCounter%37==0 || moveCounter%47==0)
            currentDirection = -currentDirection;
        attemptedAntPosition = checkBounds(attackerAntPosition + currentDirection);
        //send attempt to controller
        toController <: attemptedAntPosition;
        //recieve whether move allowed
        toController :> moveForbidden;
        //move is allowed
        if(moveForbidden == 0)
        {
            attackerAntPosition = attemptedAntPosition;
            //Update visual display with new ant position
            toVisualiser <: attackerAntPosition;
            moveCounter ++;
            printf("Attacker moved to %d\n", attackerAntPosition);
        }
        //else defender is in attempted move position.
        else if (moveForbidden == 1)
        {
            currentDirection = -currentDirection;
        }
        else if(moveForbidden == -1){
            printf("Terminated attacker \n");
            return;
        }
        //if signal = -2 then pause
        else if(moveForbidden == -2){
            //wait for controller to send resume signal
            toController :> moveForbidden;
        }
        //if signal = -3 then restart
        else if(moveForbidden == -3){
            moveCounter = 0;
            attackerAntPosition = 5;
            toVisualiser <: attackerAntPosition;
            currentDirection = 1;
            speed = 10100000;
        }

        //Delays attacker speed, progressive speedup throughout game.
        waitMoment(speed);
        if(speed > 100000)
            speed -= 100000;
    }
}

//COLLISION DETECTOR...     the controller process responds to ¿permission-to-move¿ requests
//                          from attackerAnt and userAnt. The process also checks if an attackerAnt
//                          has moved to LED positions I, XII and XI.
void controller(chanend fromAttacker, chanend fromUser) {
    int lastReportedUserAntPosition = 11;               //position last reported by userAnt
    int lastReportedAttackerAntPosition = 5;            //position last reported by attackerAnt
    int gameState = 0;                                  //0 for running, 1 for waiting for user to terminate, 2 pause, -1 terminated
    int attempt = 0;
    fromUser :> attempt;                                //start game when user moves
    fromUser <: 1;                                      //forbid first move

    while (gameState == 0 || gameState == 1)
    {
        //if attacker has been terminated
        if (gameState == 1)
        {
            //if data on channel, then clear data
            select{
                case fromUser :> int i:
                    break;
                default:
                    break;
             }
             //Send terminate signal to user
             fromUser <: -1;
             gameState = -1;     //controller ready to terminate
        }

        select
        {
            case fromAttacker :> attempt:
                printf("Request Attacker move to %d\n", attempt);
                //if move allowed
                if(attempt != lastReportedUserAntPosition)
                {
                    printf("Move Attacker allowed\n");
                    lastReportedAttackerAntPosition = attempt;
                    //victory condition - check if attacker ant has reached LED positions 1, 11 or 12.
                    if(attempt == 0 || attempt == 11 || attempt == 10)
                    {
                        //Send terminate signal to attacker
                        fromAttacker <: -1;
                        //Set terminate variable
                        gameState = 1; //Set game state to shut down user ant after attacker ant
                    }
                    else
                    {
                        //Send move allowed signal to attacker
                        fromAttacker <: 0;
                    }
                }
                //move forbidden
                else
                {
                    //Send move forbidden signal to attacker
                    fromAttacker <: 1;
                }
                break;
            case fromUser :> attempt:
                printf("Request move to %d\n", attempt);
                switch(attempt){
                    case -1:
                        printf("Pause Game\n");
                        //Recieve attempt before sending pause signal
                        fromAttacker :> attempt;
                        fromAttacker <:-2;
                        break;
                    case -2:
                        printf("Unpause Game\n");
                        //Send signal to proceed attacker ant
                        fromAttacker <:-2;
                        break;
                    case -3:
                        fromAttacker :> attempt;
                        //send reset signal to attacker, reset controller values
                        fromAttacker <: -3;
                        gameState = 0;
                        lastReportedUserAntPosition = 11;
                        lastReportedAttackerAntPosition = 5;
                        break;
                    default:
                        if(attempt != lastReportedUserAntPosition){
                            printf("Move Defender allowed\n");
                            //Send move allowed signal
                            fromUser <: 0;
                            //Update last reported position
                            lastReportedUserAntPosition = attempt;
                        }
                        else
                            //Send move forbidden signal
                            fromUser <: 1;
                        break;
                }

                break;
        }
    }
    printf("Terminated controller\n");
}



//MAIN PROCESS defining channels, orchestrating and starting the processes
int main(void)
{
    chan buttonsToUserAnt,              //channel from buttonListener to userAnt
    userAntToVisualiser,                //channel from userAnt to Visualiser
    attackerAntToVisualiser,            //channel from attackerAnt to Visualiser
    attackerAntToController,            //channel from attackerAnt to Controller
    userAntToController;                //channel from userAnt to Controller

    chan quadrant0,quadrant1,quadrant2,quadrant3; //helper channels for LED visualisation
    par
    {
        //PROCESSES FOR YOU TO EXPAND
        on stdcore[1]: userAnt(buttonsToUserAnt,userAntToVisualiser,userAntToController);
        on stdcore[2]: attackerAnt(attackerAntToVisualiser,attackerAntToController);
        on stdcore[3]: controller(attackerAntToController, userAntToController);

        //HELPER PROCESSES
        on stdcore[0]: buttonListener(buttons, speaker,buttonsToUserAnt);
        on stdcore[0]: visualiser(userAntToVisualiser,attackerAntToVisualiser,quadrant0,quadrant1,quadrant2,quadrant3);
        on stdcore[0]: showLED(cled0,quadrant0);
        on stdcore[1]: showLED(cled1,quadrant1);
        on stdcore[2]: showLED(cled2,quadrant2);
        on stdcore[3]: showLED(cled3,quadrant3);
    }
    return 0;
}
