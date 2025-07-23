classdef PatientEditorApp < matlab.apps.AppBase
    % PatientEditorApp: View and edit patients.xls grouped by Location
    
    % Properties that correspond to app components
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        GridLayout           matlab.ui.container.GridLayout
        LeftPanel            matlab.ui.container.Panel
        RightPanel           matlab.ui.container.Panel
        LocationTree         matlab.ui.container.Tree
        NameEditField        matlab.ui.control.EditField
        AgeEditField         matlab.ui.control.NumericEditField
        GenderDropDown       matlab.ui.control.DropDown
        HealthStatusEditField matlab.ui.control.DropDown
        SmokerCheckBox       matlab.ui.control.CheckBox
    end
    
    properties (Access = private)
        PatientData table
        CurrentPatientIdx double
        ExcelFilePath string = "C:\Program Files\MATLAB\R2025a_matlabonly\toolbox\matlab\demos\patients.xls"
        PrevAge
        PrevGender
        PrevHealthStatus
        PrevSmoker
    end
    
    methods (Access = private)
        function startupFcn(app)
            % Load patient data from Excel
            app.PatientData = readtable(app.ExcelFilePath);
            % Populate Health Status dropdown with unique values
            if ismember('SelfAssessedHealthStatus', app.PatientData.Properties.VariableNames)
                uniqueStatuses = unique(app.PatientData.SelfAssessedHealthStatus);
                app.HealthStatusEditField.Items = uniqueStatuses;
            end
            app.populateLocationTree();
        end
        
        function populateLocationTree(app)
            % Clear tree
            app.LocationTree.Children.delete;
            locations = unique(app.PatientData.Location);
            for i = 1:numel(locations)
                loc = locations{i};
                locNode = uitreenode(app.LocationTree, 'Text', loc, 'NodeData', loc);
                % Add dummy child node for expand affordance
                uitreenode(locNode, 'Text', 'Loading...');
            end
        end
        
        function onTreeSelectionChanged(app, event)
            node = event.SelectedNodes;
            if isempty(node) || isempty(node.NodeData)
                return;
            end
            idx = node.NodeData;
            if isnumeric(idx)
                app.CurrentPatientIdx = idx;
                app.updateDetailPanel(idx);
            else
                % Optionally clear the detail panel here if desired
            end
        end
        
        function updateDetailPanel(app, idx)
            row = app.PatientData(idx, :);
            app.NameEditField.Value = row.LastName{1};
            app.AgeEditField.Value = row.Age;
            app.GenderDropDown.Value = row.Gender{1};
            app.HealthStatusEditField.Value = row.SelfAssessedHealthStatus{1};
            app.SmokerCheckBox.Value = logical(row.Smoker);
            % Store previous values
            app.PrevAge = row.Age;
            app.PrevGender = row.Gender{1};
            app.PrevHealthStatus = row.SelfAssessedHealthStatus{1};
            app.PrevSmoker = logical(row.Smoker);
        end
        
        function onDetailChanged(app, src, event)
            if isempty(app.CurrentPatientIdx)
                return;
            end
            idx = app.CurrentPatientIdx;
            % Validate Age
            newAge = app.AgeEditField.Value;
            if src == app.AgeEditField
                if newAge <= 0 || newAge >= 200
                    uialert(app.UIFigure, 'Age must be > 0 and < 200.', 'Invalid Age');
                    app.AgeEditField.Value = app.PrevAge;
                    return;
                end
                msg = sprintf('Change Age from %d to %d?', app.PrevAge, newAge);
                choice = uiconfirm(app.UIFigure, msg, 'Confirm Change', 'Options', {'Yes','No'}, 'DefaultOption',2,'CancelOption',2,'Icon','question');
                if strcmp(choice, 'Yes')
                    app.PatientData.Age(idx) = newAge;
                    app.PrevAge = newAge;
                else
                    app.AgeEditField.Value = app.PrevAge;
                    return;
                end
            elseif src == app.GenderDropDown
                msg = sprintf('Change Gender from %s to %s?', app.PrevGender, app.GenderDropDown.Value);
                choice = uiconfirm(app.UIFigure, msg, 'Confirm Change', 'Options', {'Yes','No'}, 'DefaultOption',2,'CancelOption',2,'Icon','question');
                if strcmp(choice, 'Yes')
                    app.PatientData.Gender{idx} = app.GenderDropDown.Value;
                    app.PrevGender = app.GenderDropDown.Value;
                else
                    app.GenderDropDown.Value = app.PrevGender;
                    return;
                end
            elseif src == app.HealthStatusEditField
                msg = sprintf('Change Health Status from %s to %s?', app.PrevHealthStatus, app.HealthStatusEditField.Value);
                choice = uiconfirm(app.UIFigure, msg, 'Confirm Change', 'Options', {'Yes','No'}, 'DefaultOption',2,'CancelOption',2,'Icon','question');
                if strcmp(choice, 'Yes')
                    app.PatientData.SelfAssessedHealthStatus{idx} = app.HealthStatusEditField.Value;
                    app.PrevHealthStatus = app.HealthStatusEditField.Value;
                else
                    app.HealthStatusEditField.Value = app.PrevHealthStatus;
                    return;
                end
            elseif src == app.SmokerCheckBox
                msg = sprintf('Change Smoker from %s to %s?', mat2str(app.PrevSmoker), mat2str(app.SmokerCheckBox.Value));
                choice = uiconfirm(app.UIFigure, msg, 'Confirm Change', 'Options', {'Yes','No'}, 'DefaultOption',2,'CancelOption',2,'Icon','question');
                if strcmp(choice, 'Yes')
                    app.PatientData.Smoker(idx) = app.SmokerCheckBox.Value;
                    app.PrevSmoker = app.SmokerCheckBox.Value;
                else
                    app.SmokerCheckBox.Value = app.PrevSmoker;
                    return;
                end
            end
            % Save to Excel
            writetable(app.PatientData, app.ExcelFilePath);
        end

        function onNodeExpanded(app, event)
            node = event.Node;
            % Only expand if node is a location node
            if ischar(node.NodeData)
                % Remove dummy node if present
                if ~isempty(node.Children) && strcmp(node.Children(1).Text, 'Loading...')
                    delete(node.Children(1));
                end
                if isempty(node.Children)
                    loc = node.NodeData;
                    idx = strcmp(app.PatientData.Location, loc);
                    names = app.PatientData.LastName(idx);
                    nameIdxs = find(idx);
                    [sortedNames, sortOrder] = sort(names);
                    sortedIdxs = nameIdxs(sortOrder);
                    for j = 1:numel(sortedNames)
                        uitreenode(node, 'Text', sortedNames{j}, 'NodeData', sortedIdxs(j));
                    end
                end
            end
        end
    end
    
    methods (Access = private)
        function createComponents(app)
            % Create UIFigure and components
            app.UIFigure = uifigure('Name', 'Patient Editor', 'Position', [100 100 640 424]);
            
            app.GridLayout = uigridlayout(app.UIFigure, [1,2]);
            app.GridLayout.ColumnWidth = {'1x', '2x'};
            
            % Left panel: Tree with title and padding
            app.LeftPanel = uipanel(app.GridLayout, 'Title', '');
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            % Add a grid layout to the LeftPanel with 2 rows
            leftGrid = uigridlayout(app.LeftPanel, [2,1]);
            leftGrid.RowHeight = {30, '1x'};
            leftGrid.ColumnWidth = {'1x'};
            leftGrid.Padding = [15 15 15 15];
            % Title label, centered
            leftTitle = uilabel(leftGrid, 'Text', 'Select Patient by Location', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            leftTitle.Layout.Row = 1;
            leftTitle.Layout.Column = 1;
            % Add the tree to the grid layout
            app.LocationTree = uitree(leftGrid);
            app.LocationTree.Layout.Row = 2;
            app.LocationTree.Layout.Column = 1;
            app.LocationTree.SelectionChangedFcn = @(src, event) app.onTreeSelectionChanged(event);
            app.LocationTree.NodeExpandedFcn = @(src, event) app.onNodeExpanded(event);
            
            % Right panel: Details with title and padding
            app.RightPanel = uipanel(app.GridLayout, 'Title', '');
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;
            % Add a grid layout to the RightPanel with 2 rows (title + content)
            rightGrid = uigridlayout(app.RightPanel, [2,1]);
            rightGrid.RowHeight = {30, '1x'};
            rightGrid.ColumnWidth = {'1x'};
            rightGrid.Padding = [15 15 15 15];
            % Title label, centered
            rightTitle = uilabel(rightGrid, 'Text', 'Patient Information', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            rightTitle.Layout.Row = 1;
            rightTitle.Layout.Column = 1;
            % Add a grid layout for the two subpanels (Demographics, Self Assessment)
            detailsStack = uigridlayout(rightGrid, [2,1]);
            detailsStack.Layout.Row = 2;
            detailsStack.Layout.Column = 1;
            detailsStack.RowHeight = {'1x', '1x'};
            detailsStack.ColumnWidth = {'1x'};
            detailsStack.Padding = [0 0 0 0];
            % Demographics panel
            demoPanel = uipanel(detailsStack, 'Title', 'Demographics');
            demoPanel.Layout.Row = 1;
            demoPanel.Layout.Column = 1;
            demoGrid = uigridlayout(demoPanel, [3,2]);
            demoGrid.RowHeight = {'fit','fit','fit'};
            demoGrid.ColumnWidth = {100, '1x'};
            demoGrid.Padding = [10 10 10 10];
            % Name
            lblName = uilabel(demoGrid, 'Text', 'Name:', 'HorizontalAlignment', 'right');
            lblName.Layout.Row = 1; lblName.Layout.Column = 1;
            app.NameEditField = uieditfield(demoGrid, 'text');
            app.NameEditField.Layout.Row = 1; app.NameEditField.Layout.Column = 2;
            app.NameEditField.Editable = false; % Make read-only
            % Age
            lblAge = uilabel(demoGrid, 'Text', 'Age:', 'HorizontalAlignment', 'right');
            lblAge.Layout.Row = 2; lblAge.Layout.Column = 1;
            app.AgeEditField = uieditfield(demoGrid, 'numeric');
            app.AgeEditField.Layout.Row = 2; app.AgeEditField.Layout.Column = 2;
            app.AgeEditField.HorizontalAlignment = 'left';
            app.AgeEditField.ValueChangedFcn = @(src, event) app.onDetailChanged(src, event);
            % Gender
            lblGender = uilabel(demoGrid, 'Text', 'Gender:', 'HorizontalAlignment', 'right');
            lblGender.Layout.Row = 3; lblGender.Layout.Column = 1;
            app.GenderDropDown = uidropdown(demoGrid, 'Items', {'Male', 'Female'});
            app.GenderDropDown.Layout.Row = 3; app.GenderDropDown.Layout.Column = 2;
            app.GenderDropDown.ValueChangedFcn = @(src, event) app.onDetailChanged(src, event);
            % Self Assessment panel
            selfPanel = uipanel(detailsStack, 'Title', 'Self Assessment');
            selfPanel.Layout.Row = 2;
            selfPanel.Layout.Column = 1;
            selfGrid = uigridlayout(selfPanel, [2,2]);
            selfGrid.RowHeight = {'fit','fit'};
            selfGrid.ColumnWidth = {100, '1x'};
            selfGrid.Padding = [10 10 10 10];
            % Health Status dropdown (items set after data load)
            lblHealth = uilabel(selfGrid, 'Text', 'Health Status:', 'HorizontalAlignment', 'right');
            lblHealth.Layout.Row = 1; lblHealth.Layout.Column = 1;
            app.HealthStatusEditField = uidropdown(selfGrid, 'Items', {});
            app.HealthStatusEditField.Layout.Row = 1; app.HealthStatusEditField.Layout.Column = 2;
            app.HealthStatusEditField.ValueChangedFcn = @(src, event) app.onDetailChanged(src, event);
            % Smoker
            app.SmokerCheckBox = uicheckbox(selfGrid, 'Text', 'Smoker');
            app.SmokerCheckBox.Layout.Row = 2; app.SmokerCheckBox.Layout.Column = 2;
            app.SmokerCheckBox.ValueChangedFcn = @(src, event) app.onDetailChanged(src, event);
        end
        
        function onResize(app)
            % Let grid layout handle resizing
        end
    end
    
    methods (Access = public)
        function app = PatientEditorApp
            % Constructor
            createComponents(app);
            startupFcn(app);
        end
    end
end 