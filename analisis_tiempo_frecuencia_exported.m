classdef analisis_tiempo_frecuencia_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        TabGroup                      matlab.ui.container.TabGroup
        SalidaTab                     matlab.ui.container.Tab
        ReproducirButton              matlab.ui.control.Button
        SalirButton                   matlab.ui.control.Button
        DetenerButton                 matlab.ui.control.Button
        TiempoLabel                   matlab.ui.control.Label
        TiempoSlider                  matlab.ui.control.Slider
        RutadelArchivoEditFieldLabel  matlab.ui.control.Label
        RutadelArchivoEditField       matlab.ui.control.EditField
        BuscarButton                  matlab.ui.control.Button
        readingLabel                  matlab.ui.control.Label
        EliminarFiltroButton          matlab.ui.control.Button
        UIAxes                        matlab.ui.control.UIAxes
        UIAxes2                       matlab.ui.control.UIAxes
        FiltroTab                     matlab.ui.container.Tab
        AplicarFiltroButton           matlab.ui.control.Button
        FrecuenciadecorteEditFieldLabel  matlab.ui.control.Label
        FrecuenciadecorteEditField    matlab.ui.control.NumericEditField
        UIAxes3                       matlab.ui.control.UIAxes
        UIAxes4                       matlab.ui.control.UIAxes
        UIAxes5                       matlab.ui.control.UIAxes
    end

    
    properties (Access = public)
        Player audioplayer
        YData double
        WindowLength double = 10;
        Timer timer
    end
    
    methods (Access = public)
        
         function TimerCallback(app, src, event)
             app.TiempoSlider.Value = app.Player.CurrentSample / app.Player.SampleRate;
         end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.Timer = timer('ExecutionMode', 'fixedRate', 'Period', 0.1, 'TimerFcn', @(src, event) TimerCallback(app, src, event));
        end

        % Button pushed function: ReproducirButton
        function ReproducirButtonPushed(app, event)
            % Comienza la reproducción desde la muestra especificada por el control deslizante.
            stop(timerfindall);
            play(app.Player);
            start(app.Timer);           
        end

        % Button pushed function: SalirButton
        function SalirButtonPushed(app, event)
            stop(timerfindall);
            app.delete;
        end

        % Button pushed function: DetenerButton
        function DetenerButtonPushed(app, event)
            stop(timerfindall);
            stop(app.Player);
            app.TiempoSlider.Value = 0;
        end

        % Value changed function: TiempoSlider
        function TiempoSliderValueChanged(app, event)
            % Cambia la posición del audio a la posición indicada por el slider
            newSample = round(app.TiempoSlider.Value * app.Player.SampleRate);
            % Detiene la reproducción actual
            stop(timerfindall);
            stop(app.Player);
            start(app.Timer); 
            % Inicia la reproducción desde la nueva muestra
            play(app.Player, newSample);
        end

        % Button pushed function: BuscarButton
        function BuscarButtonPushed(app, event)
            stop(timerfindall);
            app.TiempoSlider.Value = 0;
            global f t d A_m a_m fs mag_A
            [FileName,PathName,FilterIndex] = uigetfile(...
                {'*.mp3;*.wav;*.flac','media files (*.mp3,*.wav,*.flac';...
                '*.*',  'All Files (*.*)'},'File Selector');
                isok=true;
            if length(FileName)==1
                if FileName==0
                    isok=false;
                end
            end
            if isok
                fln=[PathName FileName];
                app.RutadelArchivoEditField.Value = fln;
                app.readingLabel.Visible = 'on';
                drawnow;
                [a, fs] = audioread(fln);
                app.readingLabel.Visible = 'off';
                drawnow;
                d = length(a)/fs;
        
                % Se considera la cantidad de canales
                num_channels = size(a,2);
                a_m = sum(a, 2).' / num_channels; % audio monocanal
        
                t = linspace(0, d, length(a));
            end
    
            % Crea un objeto audioplayer y lo almacena en app.Player.
            app.Player = audioplayer(a_m, fs);
    
            % Configura el control deslizante.
            app.TiempoSlider.Limits = [0, max(t)];
    
            % Dibuja un gráfico inicial en UIAxes.
            plot(app.UIAxes, t, a_m);
    
            % Dibuja un gráfico en UIAxes2 para la frecuencia
    
            A_m = fftshift( fft(a_m) );
    
            f = linspace(-fs/2, fs/2, length(A_m));
    
            mag_A = abs(A_m);
    
            plot(app.UIAxes2, f, mag_A/max(mag_A));
            app.UIAxes2.XAxis.Exponent = 3;
            
            cla(app.UIAxes5);
    
            % Configura el slider para que tenga el mismo rango que la duración del audio
            app.TiempoSlider.Limits = [0, d];
        end

        % Button pushed function: AplicarFiltroButton
        function AplicarFiltroButtonPushed(app, event)
            global f t d A_m a_m fs mag_A
            stop(timerfindall);
            frecuencia_corte = app.FrecuenciadecorteEditField.Value;
            lpf = 1.*( abs(f) <= round(frecuencia_corte ));
            plot(app.UIAxes3, f, lpf);
            app.UIAxes3.XAxis.Exponent = 3;
            
            cla(app.UIAxes5);
            
            % Graficar la respuesta al impulso
            o=round(length(t)/2);
            lp = fftshift(lpf);
            lpf_t = fftshift(ifft(lp));
            lpf_t = lpf_t/max(lpf_t)*frecuencia_corte/pi;
            
            th = linspace(-2*pi,2*pi,length(lpf_t));
            r=[o-101:o+101];
            
            plot(app.UIAxes4, th(r), real(lpf_t(r)));
            
            A_lpf = A_m .* lpf;
            a_lpf = ifft(fftshift(A_lpf));
            a_lpf = real(a_lpf);
            
            % Crea un nuevo objeto audioplayer con el audio filtrado
            app.Player = audioplayer(a_lpf, fs);

            % Calcula la nueva muestra
            newSample = min(round(app.TiempoSlider.Value * app.Player.SampleRate), app.Player.TotalSamples);

            % Detiene la reproducción actual
            stop(app.Player);
            start(app.Timer);

            % Inicia la reproducción desde la nueva muestra
            play(app.Player, [newSample, app.Player.TotalSamples]);

            plot(app.UIAxes, t, a_lpf);
            plot(app.UIAxes2, f, abs(A_lpf)/max(abs(A_lpf)));
            
            plot(app.UIAxes5, f, mag_A/max(mag_A));
            hold(app.UIAxes5, 'on');
            plot(app.UIAxes5, f, lpf, 'r');
            legend(app.UIAxes5, 'Audio', 'Filtro');
            app.UIAxes5.XAxis.Exponent = 3;
            
        end

        % Button pushed function: EliminarFiltroButton
        function EliminarFiltroButtonPushed(app, event)
            global a_m fs t f A_m
            stop(timerfindall);
            
            % Crea un nuevo objeto audioplayer con el audio filtrado
            app.Player = audioplayer(a_m, fs);

            % Calcula la nueva muestra
            newSample = min(round(app.TiempoSlider.Value * app.Player.SampleRate), app.Player.TotalSamples);

            % Detiene la reproducción actual
            stop(app.Player);

            % Inicia la reproducción desde la nueva muestra
            start(app.Timer);
            play(app.Player, [newSample, app.Player.TotalSamples]);

            % Dibuja un gráfico inicial en UIAxes.
            plot(app.UIAxes, t, a_m);

            % Dibuja un gráfico en UIAxes2 para la frecuencia
            plot(app.UIAxes2, f, abs(A_m)/max(abs(A_m)));
            app.UIAxes2.XAxis.Exponent = 3;
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 732 480];
            app.UIFigure.Name = 'MATLAB App';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [1 1 732 480];

            % Create SalidaTab
            app.SalidaTab = uitab(app.TabGroup);
            app.SalidaTab.Title = 'Salida';

            % Create ReproducirButton
            app.ReproducirButton = uibutton(app.SalidaTab, 'push');
            app.ReproducirButton.ButtonPushedFcn = createCallbackFcn(app, @ReproducirButtonPushed, true);
            app.ReproducirButton.Position = [43 25 100 22];
            app.ReproducirButton.Text = 'Reproducir';

            % Create SalirButton
            app.SalirButton = uibutton(app.SalidaTab, 'push');
            app.SalirButton.ButtonPushedFcn = createCallbackFcn(app, @SalirButtonPushed, true);
            app.SalirButton.Position = [545 20 101 33];
            app.SalirButton.Text = 'Salir';

            % Create DetenerButton
            app.DetenerButton = uibutton(app.SalidaTab, 'push');
            app.DetenerButton.ButtonPushedFcn = createCallbackFcn(app, @DetenerButtonPushed, true);
            app.DetenerButton.Position = [192 25 100 22];
            app.DetenerButton.Text = 'Detener';

            % Create TiempoLabel
            app.TiempoLabel = uilabel(app.SalidaTab);
            app.TiempoLabel.HorizontalAlignment = 'right';
            app.TiempoLabel.Position = [53 364 48 22];
            app.TiempoLabel.Text = 'Tiempo:';

            % Create TiempoSlider
            app.TiempoSlider = uislider(app.SalidaTab);
            app.TiempoSlider.ValueChangedFcn = createCallbackFcn(app, @TiempoSliderValueChanged, true);
            app.TiempoSlider.Position = [122 373 495 3];

            % Create RutadelArchivoEditFieldLabel
            app.RutadelArchivoEditFieldLabel = uilabel(app.SalidaTab);
            app.RutadelArchivoEditFieldLabel.HorizontalAlignment = 'right';
            app.RutadelArchivoEditFieldLabel.Position = [27 414 105 22];
            app.RutadelArchivoEditFieldLabel.Text = 'Ruta del Archivo:';

            % Create RutadelArchivoEditField
            app.RutadelArchivoEditField = uieditfield(app.SalidaTab, 'text');
            app.RutadelArchivoEditField.Position = [142 414 358 22];

            % Create BuscarButton
            app.BuscarButton = uibutton(app.SalidaTab, 'push');
            app.BuscarButton.ButtonPushedFcn = createCallbackFcn(app, @BuscarButtonPushed, true);
            app.BuscarButton.Position = [528 414 100 22];
            app.BuscarButton.Text = 'Buscar';

            % Create readingLabel
            app.readingLabel = uilabel(app.SalidaTab);
            app.readingLabel.Visible = 'off';
            app.readingLabel.Position = [645 414 46 22];
            app.readingLabel.Text = 'reading';

            % Create EliminarFiltroButton
            app.EliminarFiltroButton = uibutton(app.SalidaTab, 'push');
            app.EliminarFiltroButton.ButtonPushedFcn = createCallbackFcn(app, @EliminarFiltroButtonPushed, true);
            app.EliminarFiltroButton.Position = [348 25 100 22];
            app.EliminarFiltroButton.Text = 'Eliminar Filtro';

            % Create UIAxes
            app.UIAxes = uiaxes(app.SalidaTab);
            title(app.UIAxes, 'Audio en Tiempo')
            xlabel(app.UIAxes, 'Tiempo [seg]')
            ylabel(app.UIAxes, 'Amplitud')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.XGrid = 'on';
            app.UIAxes.XMinorGrid = 'on';
            app.UIAxes.YGrid = 'on';
            app.UIAxes.YMinorGrid = 'on';
            app.UIAxes.Position = [33 84 300 213];

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.SalidaTab);
            title(app.UIAxes2, 'Audio en Frecuencia')
            xlabel(app.UIAxes2, 'Frecuencia [Hz]')
            ylabel(app.UIAxes2, 'Amplitud')
            zlabel(app.UIAxes2, 'Z')
            app.UIAxes2.XGrid = 'on';
            app.UIAxes2.XMinorGrid = 'on';
            app.UIAxes2.YGrid = 'on';
            app.UIAxes2.YMinorGrid = 'on';
            app.UIAxes2.Position = [396 84 300 213];

            % Create FiltroTab
            app.FiltroTab = uitab(app.TabGroup);
            app.FiltroTab.Title = 'Filtro';

            % Create AplicarFiltroButton
            app.AplicarFiltroButton = uibutton(app.FiltroTab, 'push');
            app.AplicarFiltroButton.ButtonPushedFcn = createCallbackFcn(app, @AplicarFiltroButtonPushed, true);
            app.AplicarFiltroButton.Position = [153 63 100 22];
            app.AplicarFiltroButton.Text = 'Aplicar Filtro';

            % Create FrecuenciadecorteEditFieldLabel
            app.FrecuenciadecorteEditFieldLabel = uilabel(app.FiltroTab);
            app.FrecuenciadecorteEditFieldLabel.HorizontalAlignment = 'right';
            app.FrecuenciadecorteEditFieldLabel.Position = [68 117 115 22];
            app.FrecuenciadecorteEditFieldLabel.Text = 'Frecuencia de corte:';

            % Create FrecuenciadecorteEditField
            app.FrecuenciadecorteEditField = uieditfield(app.FiltroTab, 'numeric');
            app.FrecuenciadecorteEditField.Position = [198 117 100 22];

            % Create UIAxes3
            app.UIAxes3 = uiaxes(app.FiltroTab);
            title(app.UIAxes3, 'Respuesta en Frecuencia')
            xlabel(app.UIAxes3, 'Frecuencia [Hz]')
            ylabel(app.UIAxes3, 'Amplitud')
            zlabel(app.UIAxes3, 'Z')
            app.UIAxes3.XGrid = 'on';
            app.UIAxes3.XMinorGrid = 'on';
            app.UIAxes3.YGrid = 'on';
            app.UIAxes3.YMinorGrid = 'on';
            app.UIAxes3.Position = [42 238 300 185];

            % Create UIAxes4
            app.UIAxes4 = uiaxes(app.FiltroTab);
            title(app.UIAxes4, 'Respuesta al Impulso')
            xlabel(app.UIAxes4, 'Tiempo [seg]')
            ylabel(app.UIAxes4, 'Amplitud')
            zlabel(app.UIAxes4, 'Z')
            app.UIAxes4.XGrid = 'on';
            app.UIAxes4.XMinorGrid = 'on';
            app.UIAxes4.YGrid = 'on';
            app.UIAxes4.YMinorGrid = 'on';
            app.UIAxes4.Position = [373 238 300 185];

            % Create UIAxes5
            app.UIAxes5 = uiaxes(app.FiltroTab);
            title(app.UIAxes5, 'Filtro vs Señal Original')
            xlabel(app.UIAxes5, 'Frecuencia [Hz]')
            ylabel(app.UIAxes5, 'Amplitud')
            zlabel(app.UIAxes5, 'Z')
            app.UIAxes5.XGrid = 'on';
            app.UIAxes5.XMinorGrid = 'on';
            app.UIAxes5.YGrid = 'on';
            app.UIAxes5.YMinorGrid = 'on';
            app.UIAxes5.Position = [373 16 300 185];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = analisis_tiempo_frecuencia_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end