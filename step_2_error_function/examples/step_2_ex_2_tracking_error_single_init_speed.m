%% description
% This script demonstrates the tracking error computation for a single
% initial condition of the TurtleBot.
%
% Author: Shreyas Kousik
% Created: 16 May 2019
% Updated: 28 Oct 2019
%
%% user parameters
% initial condition (we only care about the initial condition in speed,
% because the dynamics are position/rotation invariant)
v_0 = 1.5 ; % m/s

% command bounds
w_min = -1.0 ; % rad/s
w_max =  1.0 ; % rad/s
delta_v = 0.25 ; % m/s
v_max = 1.5 ;

% number of samples in w and v
N_samples = 4 ;

%% automated from here
% create turtlebot
A = turtlebot_agent ;

% create initial condition vector
z_0 = [0;0;0;v_0] ; % (x,y,h,v)

% create yaw commands
w_vec = linspace(w_min,w_max,N_samples) ;

% create the feasible speed commands from the initial condition
v_vec = linspace(v_0 - delta_v, v_0 + delta_v, N_samples) ;
v_vec = unique(bound_values(v_vec,[0, v_max])) ;

% get time horizon of desired trajectory
t_f = get_t_f_from_v_0(v_0) ;

% set up arrays to save x and y error data
x_err = [] ;
y_err = [] ;

%% tracking error computation loop
disp('Computing tracking error')

tic
for w_des = w_vec
    for v_des = v_vec
        % make the braking trajectory
        [T_des,U_des,Z_des] = make_turtlebot_desired_trajectory(t_f,w_des,v_des) ;
        
        % reset the robot
        A.reset(z_0)
        
        % track the desired trajectory
        A.move(T_des(end),T_des,U_des,Z_des) ;
        
        % get the realized position trajectory
        T = A.time ;
        X = A.state(A.position_indices,:) ;
        
        % interpolate the desired and realized trajectory to match
        X_des = Z_des(1:2,:) ;
        X = match_trajectories(T_des,T,X) ;
        
        % compute the tracking error
        pos_err = X - X_des ;
        
        % collect the data
        x_err = [x_err ; pos_err(1,:)] ;
        y_err = [y_err ; pos_err(2,:)] ;
        
        % % FOR DEBUGGING:
        % figure(1) ; clf ; hold on ; axis equal; grid on ;
        % plot_path(X,'b--','LineWidth',1.5) ;
        % plot(A)
        % figure(2) ; clf ; plot(pos_err')
    end
end
toc

%% fit tracking error function
% get max of absolute tracking error
x_err = abs(x_err) ;
y_err = abs(y_err) ;
x_max = max(x_err,[],1) ;
y_max = max(y_err,[],1) ;

% fit polynomial to the data
int_g_x_coeffs = polyfit(T_des,x_max,4) ;
int_g_y_coeffs = polyfit(T_des,y_max,4) ;

% take the time derivative of these to get the g functions in x and y
g_x_coeffs = polyder(int_g_x_coeffs) ;
g_y_coeffs = polyder(int_g_y_coeffs) ;

%% correct the fit to make it greater than the data
% evaluate g
int_g_x_coeffs = polyint(g_x_coeffs) ;
int_g_y_coeffs = polyint(g_y_coeffs) ;
int_g_x_vals = polyval(int_g_x_coeffs,T_des) ;
int_g_y_vals = polyval(int_g_y_coeffs,T_des) ;

% figure out the maximum ratio of the error data to the int g values
r_x_err = x_max ./ int_g_x_vals ;
r_x_max = max([1,r_x_err]) ;
r_y_err = y_max ./ int_g_y_vals ;
r_y_max = max([1,r_y_err]) ;

% multiply the g_x and g_y coefficients by the error data ratio
g_x_coeffs = r_x_max .* g_x_coeffs ;
g_y_coeffs = r_y_max .* g_y_coeffs ;

% re-integrate g with the new coefficients
int_g_x_coeffs = polyint(g_x_coeffs) ;
int_g_y_coeffs = polyint(g_y_coeffs) ;
int_g_x_vals = polyval(int_g_x_coeffs,T_des) ;
int_g_y_vals = polyval(int_g_y_coeffs,T_des) ;

%% plotting
figure(1) ; clf ;

% plot x error
subplot(2,1,1) ; hold on ;
plot(T_des,x_err','k--')
g_x_handle =  plot(T_des,int_g_x_vals,'r-','LineWidth',1.5) ;
title(['tracking error vs. time, v_0 = ',num2str(v_0,'%0.2f')])
ylabel('x error [m]')
legend(g_x_handle,'\int g_x(t) dt','Location','NorthWest')
axis([0 T_des(end) 0 0.03])
set(gca,'FontSize',15)

% plot y error
subplot(2,1,2) ; hold on ;
plot(T_des,y_err','k--')
g_y_handle = plot(T_des,int_g_y_vals,'r-','LineWidth',1.5) ;
xlabel('% of trajectory')
ylabel('y error [m]')
legend(g_y_handle,'\int g_y(t) dt','Location','NorthWest')
axis([0 T_des(end) 0 0.01])
set(gca,'FontSize',15)