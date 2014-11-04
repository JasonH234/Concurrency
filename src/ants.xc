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

//DISPLAYS an LED pattern in one quadrant of the clock LEDs
int showLED(out port p, chanend fromVisualiser)
{
    //Variable that determines which LED in quadrant to light up
    int lightUpPattern = 0;

    //Loop until game end signal (-1) is received
    while (lightUpPattern != -1)
    {
        //Awaiting to receive data from the visualiser
        fromVisualiser :> lightUpPattern;
        //Send the light pattern to the LEDs
        p <: lightUpPattern;
    }
    //Turn off LEDs with signal (0) when terminating showLED gracefully
    p <: 0;
    //printf("Terminated showLED\n");
    return 0;
}

//PROCESS TO COORDINATE DISPLAY of LED Ants
void visualiser(chanend fromUserAnt, chanend fromAttackerAnt, chanend toQuadrant0, chanend toQuadrant1, chanend toQuadrant2, chanend toQuadrant3)
{
    //Initial positions to display
    int userAntToDisplay = 11;
    int attackerAntToDisplay = 5;

    int i, j;
    //Activating green LEDs
    cledG <: 1;
    while (userAntToDisplay != -1)
    {
        //Wait until signal is received from either user or attacker ant
        select
        {
            case fromUserAnt :> userAntToDisplay:
                break;
            case fromAttackerAnt :> attackerAntToDisplay:
                break;
        }
        //pre-termination lightup
        if(userAntToDisplay == -2){
            cledG <: 0;
            cledR <: 1;
            toQuadrant0 <: 112;
            toQuadrant1 <: 112;
            toQuadrant2 <: 112;
            toQuadrant3 <: 112;
        }
        else{
            //Setting quadrants and LEDs with the respective bit patterns
            j = 16<<(userAntToDisplay%3);
            i = 16<<(attackerAntToDisplay%3);
            toQuadrant0 <: (j*(userAntToDisplay/3==0)) + (i*(attackerAntToDisplay/3==0)) ; /*0b01110000;*/
            toQuadrant1 <: (j*(userAntToDisplay/3==1)) + (i*(attackerAntToDisplay/3==1)) ;
            toQuadrant2 <: (j*(userAntToDisplay/3==2)) + (i*(attackerAntToDisplay/3==2)) ;
            toQuadrant3 <: (j*(userAntToDisplay/3==3)) + (i*(attackerAntToDisplay/3==3)) ;
        }
    }
    //Ending by passing game end signal to the quadrants and turning them off
    if (userAntToDisplay == -1)
    {
        toQuadrant0 <: -1;
        toQuadrant1 <: -1;
        toQuadrant2 <: -1;
        toQuadrant3 <: -1;
        //printf("Terminated visualiser\n");
        return;
    }
}

//PLAYS a short sound (pls use with caution and consideration to other students in the labs!) Yes sir
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
  //Loops until return statement
  while (1) {
    select
    {
        //Terminate when receiving signal from the user ant
        case toUserAnt :> r:
                //printf("Terminated buttonListener, r == %d\n", r);
                return;
                break;
        //Otherwise when nothing is pressed send button pattern to user ant
        case b when pinsneq(15) :> r:
            //printf("r == %d\n", r);
            playSound(2000000,spkr);
            toUserAnt <: r;
            //Wait to prevent skipping termination from constant sending
            waitMoment(300000);
            break;
    }
  }
}

//Bounds Check for position
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

//The function that checks the attempted moves and determines how the ant functions react.
int attemptMove(int attemptedAntPosition, int userAntPosition, chanend toController, chanend toVisualiser){
    //The variable that determines whether a move is allowed. Terminate if (-1).
    int moveForbidden = 0;

    select{
        //If moveForbidden is received, continue
        case toController :> moveForbidden:
            break;
        //Otherwise send attempted position to controller and wait for moveForbidden
        default:
            toController <: attemptedAntPosition;
            toController :> moveForbidden;
            break;
    }

    //If move is allowed, set user ant position and update the visualiser.
    if(moveForbidden == 0)
    {
        userAntPosition = attemptedAntPosition;
        //Update visual display with new ant position
        toVisualiser <: userAntPosition;
        //printf("Defender moved to %d\n", userAntPosition);
    }
    //Otherwise disallow the move
    else
    {
        //printf("Move to %d not allowed\n", userAntPosition);
        //Check if the game has ended
        if(moveForbidden == -1){
            //Set terminate signal to return
            userAntPosition = -1;
        }
    }
    return userAntPosition;
}

//The pause function holds the game and handles the pausing through toggling mechanism
void pauseGame(chanend fromButtons, chanend toController){
    //Resetting buttonInput for pause toggle functionality
    int buttonInput = 0;
    //Send pause signal (-1) to controller
    toController <: -1;
    //Await continuation
    //Wait to prevent pausing immediately ***To set appropriate amount/solution
    while (buttonInput != 13)
        fromButtons :> buttonInput;
    //buttonInput = 0; <- try this to toggle
    //Initiate unpause condition
    toController <: -2;
}

//This function tells the visualiser and  button listener to terminate when the defender is terminating
void terminateButtons(chanend fromButtons, chanend toVisualiser){
    //send signal to flash red lights to indicate loss.
    toVisualiser <: -2;
    waitMoment(50000000);
    //terminate visualiser
    toVisualiser <: -1;
    waitMoment(10000000);
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

//This function handles the button input from the button listener
int buttonPressed(int buttonInput, int userAntPosition, chanend fromButtons, chanend toController, chanend toVisualiser){
    //Declaring attempted position
    int attemptedAntPosition;

    switch(buttonInput){
        //Move anti-clockwise
        case 7:
            attemptedAntPosition = checkBounds(userAntPosition -1);
            userAntPosition = attemptMove(attemptedAntPosition, userAntPosition, toController, toVisualiser);
            break;
        //Restarting the game
        case 11:
            userAntPosition = 11;
            toVisualiser <: userAntPosition;
            toController <: -3;
            break;
        //Pause and unpausing
        case 13:
            pauseGame(fromButtons, toController);
            break;
        case 14:
            //Move clockwise
            attemptedAntPosition = checkBounds(userAntPosition +1);
            userAntPosition = attemptMove(attemptedAntPosition, userAntPosition, toController, toVisualiser);
            break;
    }
    return userAntPosition;
}

//This is the main function for the user ant
void userAnt(chanend fromButtons, chanend toVisualiser, chanend toController)
{
    //The current defender position
    int userAntPosition = 11;
    //Input pattern from buttonListener
    int buttonInput;
    //Signal from controller
    int controllerSignal;
    //Showing the initial position before starting
    toVisualiser <: userAntPosition;
    //Wait for the first button input before starting the game
    fromButtons :> buttonInput;

    while (1)
    {
        select
        {
            //When signal received from controller, set terminate variable
            case toController :> controllerSignal:
                userAntPosition = -1;
                break;
            //When signal received from button listener, call buttonPressed function
            case fromButtons :> buttonInput:
                userAntPosition = buttonPressed(buttonInput, userAntPosition, fromButtons, toController, toVisualiser);
                break;
        }
        //If terminate variable set, call terminate function and return
        if(userAntPosition == -1){
            terminateButtons(fromButtons, toVisualiser);
            //printf("Terminated defender\n");
            return;
        }
    }
}

//This is the main function for the attacker ant
void attackerAnt(chanend toVisualiser, chanend toController)
{
    //The move counter is used to calculate score and determine whether the attacker should turn
    int moveCounter = 0;
    //Declaring variables
    int attackerAntPosition = 5;
    int attemptedAntPosition;
    int currentDirection = 1;
    int moveForbidden = 0;
    //Show initial position
    toVisualiser <: attackerAntPosition;
    //Set speed of execution for wait function.
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
            //printf("Attacker moved to %d\n", attackerAntPosition);
        }
        //else defender is in attempted move position.
        else if (moveForbidden == 1)
        {
            currentDirection = -currentDirection;
        }
        else if(moveForbidden == -1){
            //printf("Terminated attacker \n");
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
            //speed = 10000000;
        }

        //Delays attacker speed, progressive speedup throughout game.
        waitMoment(speed);
    /*    if(speed > 100000)
            speed -= 10000;*/
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
        select
        {
            case fromAttacker :> attempt:
                //printf("Request Attacker move to %d\n", attempt);
                //if move allowed
                if(attempt != lastReportedUserAntPosition)
                {
                    //printf("Move Attacker allowed\n");
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
                //printf("Request move to %d\n", attempt);
                switch(attempt){
                    case -1:
                        //printf("Pause Game\n");
                        //Recieve attempt before sending pause signal
                        fromAttacker :> attempt;
                        fromAttacker <:-2;
                        break;
                    case -2:
                        //printf("Unpause Game\n");
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
                        if(attempt != lastReportedAttackerAntPosition){
                            //printf("Move Defender allowed\n");
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
                default:
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
                    break;
        }
    }
    //printf("Terminated controller\n");
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
