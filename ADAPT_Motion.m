%% MRC fixes to ADDaPT

%----------Patient Settings----------%
Patient_ID              = 'EVROS12_071626';       % Input an identifier for the subject to be tested
Deficit_Side            = 'left';           % Specify the side of the visual field to be tested ("left" or "right")
Testing_Mode            = 'sequential';     % Choose the paradigm: "sequential" or "random"

% Initialize parameters
samplingInterval                = 5;
testsPerLoc                     = 10;
testingDepth                    = 4;
testingHeight                   = 7;
startingX                       = 3;
startingY                       = -15;
xTestLocs                       = zeros(testingDepth,1);
yTestLocs                       = zeros(testingHeight,1);

% Generate testing structure
% Increments by sampling interval from a starting point up to generate x
% and y axes of interest. Default is right visual field
for counter = 1:testingDepth
    xTestLocs(counter) = startingX+samplingInterval*(counter-1);
end
xTestLocs = [-xTestLocs(1);xTestLocs];

for counter = 1:testingHeight
    yTestLocs(counter) = startingY+samplingInterval*(counter-1);
end
yTestLocs = sortrows(yTestLocs,'descend')';

% Duplicate axes by number of tests and testing depth to generate entire
% testing structure
xTestLocs = repelem(xTestLocs, testsPerLoc, size(yTestLocs,2));
xTestLocs = reshape(xTestLocs,1,[])';
yTestLocs = repelem(yTestLocs, testsPerLoc*(testingDepth+1))'; % Adds one to testingDepth to account for intact field location being added

% Remove locations that fall outside the HVF field of view
yTestLocs(341:end) = [];
yTestLocs(41:50) = [];

xTestLocs(341:end) = [];
xTestLocs(41:50) = [];

% Add Zero axis final test
xTestLocs = [xTestLocs(1:190);zeros(10,1)+23;xTestLocs(191:end)];
yTestLocs = [yTestLocs(1:190);zeros(10,1);yTestLocs(191:end)];

% Invert x-axis if testing left side of visual field
if strcmp (Deficit_Side, 'left')
    xTestLocs = -xTestLocs;
end

% If testing mode is 'random', shuffle the trial order for testing locations
if strcmp(Testing_Mode, 'random')
    xTestLocs = Shuffle(xTestLocs);
    yTestLocs = Shuffle(yTestLocs);
end

%-------Eyetracking Settings-----------------%
% Set the fixation point's horizontal and vertical eccentricity (in degrees)
H_ecc_fix               = 0;
V_ecc_fix               = 0;

%-----Apparatus Settings---------------------%
% Adjust variables to match testing rig settings
viewing_dist            = 42;                   % Viewing distance in centimeters
screen_width            = 54.5;                 % Screen horizontal width in centimeters
resolution              = [1920 1080];          % Display resolution [width height]
frame_rate              = 120;                  % Monitor frame rate in Hz

theta                   = atand((screen_width/2)/viewing_dist); % Calculate half-angle of the screen's visual field
scale_factor            = theta*60/(resolution(1)/2);           % Conversion factor from degrees to pixels (approx.)
ISI                     = (1/frame_rate)*1000;                  % Inter-stimulus interval in ms (frame duration)
windowRect              = [];                                   % Default window rectangle (full screen)

% Beautification (visual settings)
font                    = 'Arial';
fontSize                = 20;
background              = 128;                                  % Background gray level (0-255)

%%% Open Screens to be used in session
screens                 = Screen('Screens');                    % Get available screens
screenNumber            = max(screens);                         % Choose the screen with the highest number (usually external monitor)
[w, rect]               = Screen('OpenWindow',screenNumber,0,windowRect,[],2); % Open Psychtoolbox window
screen_rect             = Screen('Rect',w);                     % Get window dimensions

% Add path to folder containing MATLAB maintenance files (calibration, monitor, and setup)

% Load monitor calibration settings (adjust as needed)
addpath('~/Desktop/Matlab Maintenance');
load 'Alienware_room2_082922_cubic.mat'
Screen('LoadNormalizedGammaTable',screenNumber,gTmp); % Apply gamma correction. gTmp variable stored in calibration file

% Set blending function for transparency and clear the screen
Screen(w, 'BlendFunction', GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
Screen('FillRect',w, background);
Screen('Flip', w); 
Screen('FillRect',w, background);  
Screen('TextSize',w, fontSize);
Screen('TextFont',w, font);

%---------------Eyetracking----------------%
% Commands specific to Eyelink environment, code untested with alternative eyetrackers
ET                              = 1;            % Toggle eyetracking: 0 = off, 1 = on
fixated                         = 1;
pref_eye                        = 2;

% Calculate screen center and fixation coordinates in pixels
sr_hor                          = round(screen_rect(3)/2);
sr_ver                          = round(screen_rect(4)/2);
fix_hor                         = sr_hor+H_ecc_fix;
fix_ver                         = sr_ver+V_ecc_fix;

% Initialize the Eyelink system with fixation parameters and window info
if ET
    [fix_box, el] = setupEyelink(Patient_ID, scale_factor, fix_hor, fix_ver, w, screen_rect, rect);
end

% ---------------Stimulus and Trial Parameters---------------%
overTrial               = 1;
n_trials                = 1;

% Random dot stimulus parameters
stimulus_duration       = 500;    % Duration of the stimulus in ms
aperture_radius         = 2.5;    % Aperture radius in degrees
dot_density             = 3.5;    % Dot density (dots per degree^2)
dot_size                = 14;     % Dot size (will be adjusted by scale factor)
dot_color               = 0;      % Dot color (black)
dot_speed               = 10;     % Dot speed (deg/sec, later converted to pixels/frame)
dot_lifetime            = 200;    % Dot lifetime in ms
trial_angle_range       = [360 270 180 90]; % [45 135 225 315]; % [360 270 180 90]; % Possible dot motion angles (in degrees)
ndots                   = round(aperture_radius^2*pi*dot_density); % Number of dots computed from area and density

%%% Initialize performance variables and convert stimulus parameters to pixels
aperture_radius         = 60*aperture_radius/scale_factor; % Convert aperture radius to pixels
stimulus_radius         = aperture_radius;           % Set stimulus radius equal to aperture radius
dot_size                = dot_size/scale_factor;     % Adjust dot size for screen scale
mv_length               = round(stimulus_duration/(1000/frame_rate)); % Number of frames in the stimulus movie

% Initialize cell arrays to store dot ages and positions for each frame
age{1,mv_length}        = [];
age(1:mv_length)        = {zeros(1, ndots)};
positions               = cell(2, mv_length);

%-----Stimulus Rectangles (Mask/Envelope)---------------%
ii                      = 1;
stimulus_radius         = round(stimulus_radius); % Ensure integer value for meshgrid
bps                     = (stimulus_radius(ii))*2+1; % Size of the grid in pixels

dot_step                = dot_speed*60/scale_factor/(1000/ISI); % Recalculate dot step
Velocity                = dot_step;
lifetime                = dot_lifetime/(1000/frame_rate); % Dot lifetime in frames
trial                   = 1;
correct_trials          = 0;
results                 = zeros(length(xTestLocs),6);

%-----------------Main Experimental Loop-----------------%
while trial < length(xTestLocs) + 1
    
    % Determine target stimulus position (in degrees) for current trial
    H_ecc_stim  = xTestLocs(trial);      % X location in degrees of target stimulus
    V_ecc_stim  = -yTestLocs(trial);     % Y location in degrees (inverted to match screen coordinates)
    h_ecc_orig  = H_ecc_stim;           % Store original X position
    v_ecc_orig  = V_ecc_stim;           % Store original Y position
    
    % Convert stimulus and fixation positions from degrees to pixels
    H_ecc_stim  = H_ecc_stim * 60 / scale_factor;
    H_ecc_fix   = H_ecc_fix * 60 / scale_factor;
    V_ecc_stim  = V_ecc_stim * 60 / scale_factor;
    V_ecc_fix   = V_ecc_fix * 60 / scale_factor;
    
    % Define the rectangle for the stimulus movie patch
    movie_rect          = [0, 0, bps, bps];
    scr_left_middle     = fix(screen_rect(3)/2) - round(bps/2);
    scr_top             = fix(screen_rect(4)/2) - round(bps/2);
    screen_rect_middle  = movie_rect + [scr_left_middle, scr_top, scr_left_middle, scr_top];
    screen_patch        = screen_rect_middle + [H_ecc_stim, V_ecc_stim, H_ecc_stim, V_ecc_stim];
    stim_hor            = sr_hor + H_ecc_stim;
    stim_ver            = sr_ver + V_ecc_stim;
    fix_rect            = SetRect(0, 0, 5*scale_factor, 5*scale_factor); % Create a fixation rectangle
    fix_rect            = CenterRectOnPoint(fix_rect, fix_hor, fix_ver);  % Center the fixation box on the fixation point
    
    % Randomly select a motion angle for this trial from trial_angle_range
    angle_range = trial_angle_range(randi(end));
    
    % -----Initialize dot positions for the first frame-----
    positions{1}(:,1) = (rand(ndots,1) - 0.5) * bps;
    positions{1}(:,2) = (rand(ndots,1) - 0.5) * bps;
    
    % Ensure all dots are placed within the circular stimulus boundary
    for i = 1:ndots
        while sqrt(positions{1}(i,1)^2 + positions{1}(i,2)^2) > stimulus_radius
            positions{1}(i,:) = [ceil((rand - 0.5)*bps), ceil((rand - 0.5)*bps)];
        end
    end
    
    % Set movement directions for dots (convert angle to radians)
    vectors = pi * (angle_range + (normrnd(0,0,ndots,1))) / 180;
    
    % -----Initialize dot lifetimes for the first frame-----
    age{1} = ceil(lifetime * rand(ndots,1))';

    % Update dot positions, ages, and handle dot recycling across frames
    for j = 2:mv_length
        % ----------Update Dots----------
        for i = 1:ndots
            % Move dots according to velocity and assigned vector direction
            positions{j}(i,1) = positions{j-1}(i,1) + Velocity * cos(vectors(i));
            positions{j}(i,2) = positions{j-1}(i,2) + Velocity * sin(vectors(i));
            
            while sqrt(positions{j}(i,1)^2 + positions{j}(i,2)^2) > stimulus_radius
                
                positions{j}(i,1) = positions{j}(i,1) - (positions{j}(i,1)*1.99);
                positions{j}(i,2) = positions{j}(i,2) - (positions{j}(i,2)*1.99);
                
            end
            
            % Increase dot age
            age{j}(i) = age{j-1}(i) + 1;
            
            % If dot's age exceeds its lifetime, respawn it at a new random location
            if age{j}(i) > lifetime
                positions{j}(i,1) = (rand - 0.5) * bps;
                positions{j}(i,2) = (rand - 0.5) * bps;
                age{j}(i) = 1;
            end
            
            % Wrap dots around if they exit the defined aperture (toroidal boundary)
%             if positions{j}(i,1) > aperture_radius
%                 positions{j}(i,1) = positions{j}(i,1) - bps;
%             elseif positions{j}(i,1) < -aperture_radius
%                 positions{j}(i,1) = positions{j}(i,1) + bps;
%             elseif positions{j}(i,2) > aperture_radius
%                 positions{j}(i,2) = positions{j}(i,2) - bps;
%             elseif positions{j}(i,2) < -aperture_radius
%                 positions{j}(i,2) = positions{j}(i,2) + bps;
%             end
            
            % Ensure dot remains within the circular stimulus area
            while sqrt(positions{j}(i,1)^2 + positions{j}(i,2)^2) > stimulus_radius
                positions{j}(i,:) = [ceil((rand - 0.5)*bps), ceil((rand - 0.5)*bps)];
            end
        end
    end
    
    % Draw initial fixation screen
    Screen('FillRect', w, background);
    Screen('FillOval', w, 0, fix_rect);
    Screen('Flip', w);
    
    % Start eyetracking for the stimulus
    if ET
        [fixated] = startStimulusEyelink(trial, n_trials, pref_eye, w, fix_box, fix_hor, fix_ver);
    end
    
    Beeper(1000); % Signal stimulus onset with a beep
    
    % ------Stimulus Presentation Loop------
    i = 1;
    while i <= mv_length
        Screen('FillRect', w, background);
        % Draw moving dots relative to the stimulus location
        Screen(w, 'DrawDots', transpose(positions{i}), dot_size, dot_color, [stim_hor stim_ver], 2);
        Screen('FillOval', w, 0, fix_rect); % Redraw fixation point
        Screen('Flip', w);
        i = i + 1;
        if i > mv_length
            break
        end

        % During stimulus presentation, check for fixation breaks via Eyelink
        if ET        
           Eyelink('Command', 'draw_cross %d %d 15', fix_hor, fix_ver);
           [breakFlag] = duringStimulusEyelink(w, fix_box, pref_eye);
           if breakFlag
               fixated = 0;
               break;
           end
        end
    end

    % Clear screen and redraw fixation after stimulus presentation
    Screen('FillRect', w, background);
    Screen('FillOval', w, 0, fix_rect);
    Screen('Flip', w);
    
    tic;              % Start reaction time timer
    Priority(0);      % Reset process priority
    
    % -------- Collect Response --------
    if ET && fixated == 1
        Eyelink('Message', 'Successfuly Fixated Trial');
    end
    
    if fixated == 0
        % If fixation was broken, wait briefly and stop recording
        WaitSecs(0.1);
        Eyelink('StopRecording');
    else
        % -------- Determine Correct Response Based on Motion Angle --------
        if angle_range == 270
            correct = 'UpArrow';
            incorrect = ['DownArrow' 'LeftArrow' 'RightArrow'];
        elseif angle_range == 180
            correct = 'LeftArrow';
            incorrect = ['DownArrow' 'UpArrow' 'RightArrow'];
        elseif angle_range == 90
            correct = 'DownArrow';
            incorrect = ['LeftArrow' 'UpArrow' 'RightArrow'];
        elseif angle_range == 360
            correct = 'RightArrow';
            incorrect = ['LeftArrow' 'UpArrow' 'DownArrow'];
        else
            correct = 'UpArrow';
            incorrect = 'DownArrow';
        end        

        % -------- Wait for and Evaluate Response --------
        validKey = 0;
        while ~validKey
            [secs, keyCode, deltaSecs] = KbWait(-1);
            if keyCode(KbName(correct))
                correct_trials = correct_trials + 1;
                rs = 1;         % Mark as a correct response
                validKey = 1;
            elseif keyCode(KbName('Escape'))
                EyelinkDoTrackerSetup(el);
            else
                rs = 0;         % Mark as an incorrect response
                validKey = 1;
            end
            % Provide auditory feedback based on response accuracy
            if rs == 0
                Beeper(600);
                Beeper(400);
            elseif rs == 1
                Beeper(1100);
            end
        end
        
        % -------- Record and Save Trial Data --------
        if fixated
            reaction_time = toc;  % Capture reaction time
            results(overTrial,1) = overTrial;
            results(overTrial,4) = angle_range;
            results(overTrial,2) = h_ecc_orig;
            results(overTrial,3) = -v_ecc_orig;
            results(overTrial,5) = rs;
            results(overTrial,6) = fixated;
            
            overTrial = overTrial + 1;
            trial = trial + 1;
            
            % Briefly display fixation point before the next trial
            Screen('FillOval', w, 0, fix_rect);
            Screen('Flip', w); 
            WaitSecs(0.5);
        end
    end
end

%-------Save-------------------------------%
% Change directory to the folder where subject data will be saved
cd('~/Desktop/Subjects')

% Save the results file with a name based on Patient_ID and Testing_Mode
save(strcat(Patient_ID, Testing_Mode));

clear mex
close all