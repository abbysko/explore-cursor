classdef PatientEditorApp < matlab.apps.AppBase
    %% PatientEditorApp
    % -----------------
    % MATLAB App for viewing and editing patient data from patients.xls.
    % - Patients are grouped by Location in a tree (left panel).
    % - Selecting a patient shows editable details (right panel).
    % - Edits are confirmed before saving to Excel.
    % - Tree uses lazy loading for performance.
    %
    % Author: <Your Name>
    % Date: <Date>

    %% Public UI Properties
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        GridLayout           matlab.ui.container.GridLayout
        LeftPanel            matlab.ui.container.Panel
        RightPanel           matlab.ui.container.Panel
        LocationTree         matlab.ui.container.Tree
        NameEditField        matlab.ui.control.EditField
        AgeEditField         matlab.ui.control.NumericEditField
        GenderDropDown       matlab.ui.control.DropDown
        HealthStatusDropDown matlab.ui.control.DropDown
        SmokerCheckBox       matlab.ui.control.CheckBox
    end

    %% Private Data Properties
    properties (Access = private)
        PatientData table                % Table of patient data
        CurrentPatientIdx double         % Index of selected patient
        ExcelFilePath string = "C:\Program Files\MATLAB\R2025a_matlabonly\toolbox\matlab\demos\patients.xls" % Data file
        
        % Previous values for confirmation dialogs
        PrevValue
    end

    methods (Access = public)
        function app = PatientEditorApp
            % Constructor: create UI and load data
            createComponents(app);
            startupFcn(app);
        end
    end

    methods (Access = private)
        function createComponents(app)
            % Create UIFigure and main layout
            app.UIFigure = uifigure('Name', 'Patient Editor', 'Position', [100 100 640 424]);
            app.GridLayout = uigridlayout(app.UIFigure, [1,2]);
            app.GridLayout.ColumnWidth = {'1x', '2x'};

            %% Left Panel: Tree with Title
            app.LeftPanel = uipanel(app.GridLayout, 'Title', '');
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            leftGrid = uigridlayout(app.LeftPanel, [2,1]);
            leftGrid.RowHeight = {30, '1x'};
            leftGrid.ColumnWidth = {'1x'};
            leftGrid.Padding = [15 15 15 15];
            leftTitle = uilabel(leftGrid, 'Text', 'Select Patient by Location', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            leftTitle.Layout.Row = 1;
            leftTitle.Layout.Column = 1;
            app.LocationTree = uitree(leftGrid);
            app.LocationTree.Layout.Row = 2;
            app.LocationTree.Layout.Column = 1;
            app.LocationTree.SelectionChangedFcn = @(src, event) app.onTreeSelectionChanged(event);
            app.LocationTree.NodeExpandedFcn = @(src, event) app.onNodeExpanded(event);

            %% Right Panel: Details with Title and Two Subpanels
            app.RightPanel = uipanel(app.GridLayout, 'Title', '');
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;
            rightGrid = uigridlayout(app.RightPanel, [2,1]);
            rightGrid.RowHeight = {30, '1x'};
            rightGrid.ColumnWidth = {'1x'};
            rightGrid.Padding = [15 15 15 15];
            rightTitle = uilabel(rightGrid, 'Text', 'Patient Information', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            rightTitle.Layout.Row = 1;
            rightTitle.Layout.Column = 1;
            detailsStack = uigridlayout(rightGrid, [2,1]);
            detailsStack.Layout.Row = 2;
            detailsStack.Layout.Column = 1;
            detailsStack.RowHeight = {'1x', '1x'};
            detailsStack.ColumnWidth = {'1x'};
            detailsStack.Padding = [0 0 0 0];

            % Demographics Panel
            demoPanel = uipanel(detailsStack, 'Title', 'Demographics');
            demoPanel.Layout.Row = 1;
            demoPanel.Layout.Column = 1;
            demoGrid = uigridlayout(demoPanel, [3,2]);
            demoGrid.RowHeight = {'fit','fit','fit'};
            demoGrid.ColumnWidth = {100, '1x'};
            demoGrid.Padding = [10 10 10 10];
            lblName = uilabel(demoGrid, 'Text', 'Name:', 'HorizontalAlignment', 'right');
            lblName.Layout.Row = 1; lblName.Layout.Column = 1;
            app.NameEditField = uieditfield(demoGrid, 'text');
            app.NameEditField.Layout.Row = 1; app.NameEditField.Layout.Column = 2;
            app.NameEditField.Editable = false; % Read-only
            lblAge = uilabel(demoGrid, 'Text', 'Age:', 'HorizontalAlignment', 'right');
            lblAge.Layout.Row = 2; lblAge.Layout.Column = 1;
            app.AgeEditField = uieditfield(demoGrid, 'numeric', 'Limits', [1 199]);
            app.AgeEditField.Layout.Row = 2; app.AgeEditField.Layout.Column = 2;
            app.AgeEditField.HorizontalAlignment = 'left';
            app.AgeEditField.ValueChangedFcn = @(src, event) app.onDetailChanged(src, event);
            lblGender = uilabel(demoGrid, 'Text', 'Gender:', 'HorizontalAlignment', 'right');
            lblGender.Layout.Row = 3; lblGender.Layout.Column = 1;
            app.GenderDropDown = uidropdown(demoGrid, 'Items', {'Male', 'Female'});
            app.GenderDropDown.Layout.Row = 3; app.GenderDropDown.Layout.Column = 2;
            app.GenderDropDown.ValueChangedFcn = @(src, event) app.onDetailChanged(src, event);

            % Self Assessment Panel
            selfPanel = uipanel(detailsStack, 'Title', 'Self Assessment');
            selfPanel.Layout.Row = 2;
            selfPanel.Layout.Column = 1;
            selfGrid = uigridlayout(selfPanel, [2,2]);
            selfGrid.RowHeight = {'fit','fit'};
            selfGrid.ColumnWidth = {100, '1x'};
            selfGrid.Padding = [10 10 10 10];
            lblHealth = uilabel(selfGrid, 'Text', 'Health Status:', 'HorizontalAlignment', 'right');
            lblHealth.Layout.Row = 1; lblHealth.Layout.Column = 1;
            app.HealthStatusDropDown = uidropdown(selfGrid, 'Items', {});
            app.HealthStatusDropDown.Layout.Row = 1; app.HealthStatusDropDown.Layout.Column = 2;
            app.HealthStatusDropDown.ValueChangedFcn = @(src, event) app.onDetailChanged(src, event);
            app.SmokerCheckBox = uicheckbox(selfGrid, 'Text', 'Smoker');
            app.SmokerCheckBox.Layout.Row = 2; app.SmokerCheckBox.Layout.Column = 2;
            app.SmokerCheckBox.ValueChangedFcn = @(src, event) app.onDetailChanged(src, event);
        end

        function startupFcn(app)
            
            app.PatientData = readtable(app.ExcelFilePath);
            
            app.populateHealthStatusDropDown();
            app.populateLocationTree();
        end

        function populateHealthStatusDropDown(app)
            % Populate the Health Status dropdown with unique values
            if ismember('SelfAssessedHealthStatus', app.PatientData.Properties.VariableNames)
                uniqueStatuses = unique(app.PatientData.SelfAssessedHealthStatus);
                app.HealthStatusDropDown.Items = uniqueStatuses;
            else
                app.HealthStatusDropDown.Items = {};
            end
        end

        function populateLocationTree(app)
            % Populate the tree with location nodes (lazy loading)
            app.LocationTree.Children.delete;
            locations = unique(app.PatientData.Location);
            for i = 1:numel(locations)
                loc = locations{i};
                locNode = uitreenode(app.LocationTree, 'Text', loc, 'NodeData', loc);
                % Add dummy child node for expand affordance
                uitreenode(locNode, 'Text', 'Loading...');
            end
        end

        function onNodeExpanded(app, event)
            % Lazy-load patient nodes when a location node is expanded
            node = event.Node;
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

        function onTreeSelectionChanged(app, event)
            % Handle selection in the tree
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
            % Update the right panel with selected patient details
            row = app.PatientData(idx, :);
            app.NameEditField.Value = row.LastName{1};
            app.AgeEditField.Value = row.Age;
            app.GenderDropDown.Value = row.Gender{1};
            app.HealthStatusDropDown.Value = row.SelfAssessedHealthStatus{1};
            app.SmokerCheckBox.Value = logical(row.Smoker);
            % Store previous value for confirmation dialogs (default to Age)
            app.PrevValue = row.Age;
        end

        function confirmAndApplyChange(app, fieldName, component, tableVar)
            tableIdx = app.CurrentPatientIdx;
            if isempty(tableIdx)
                return;
            end
            prevValue = app.PrevValue;
            newValue = component.Value;
            % Helper to confirm a change, update table, or revert UI
            msg = sprintf('Change %s from %s to %s?', fieldName, mat2str(prevValue), mat2str(newValue));
            choice = uiconfirm(app.UIFigure, msg, 'Confirm Change', 'Options', {'Yes','No'}, 'DefaultOption',2,'CancelOption',2,'Icon','question');
            if strcmp(choice, 'Yes')
                % Update table (handle cell arrays for char/categorical)
                if iscell(app.PatientData.(tableVar))
                    app.PatientData.(tableVar){tableIdx} = newValue;
                else
                    app.PatientData.(tableVar)(tableIdx) = newValue;
                end
            else
                component.Value = prevValue;
            end
        end

        function onDetailChanged(app, src, event)
            % Handle edits to patient details with confirmation dialog
            if isempty(app.CurrentPatientIdx)
                return;
            end

            app.PrevValue = event.PreviousValue;
            if src == app.AgeEditField    
                app.confirmAndApplyChange('Age', app.AgeEditField, 'Age');
            elseif src == app.GenderDropDown
                app.confirmAndApplyChange('Gender', app.GenderDropDown, 'Gender');
            elseif src == app.HealthStatusDropDown
                app.confirmAndApplyChange('Health Status',app.HealthStatusDropDown, 'SelfAssessedHealthStatus');
            elseif src == app.SmokerCheckBox
                app.confirmAndApplyChange('Smoker', app.SmokerCheckBox, 'Smoker');
            end
            % Save to Excel
            writetable(app.PatientData, app.ExcelFilePath);
        end
    end
end 