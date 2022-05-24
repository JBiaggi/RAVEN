function writeYaml(model,name,preserveQuotes,sortIds)
% writeYaml
%   Writes a yaml file matching (roughly) the cobrapy yaml structure
%
%   model           a model structure
%   name            name that the file will have
%   preserveQuotes  if quotes should be preserved for strings
%                   (logical, default=true)
%   sortIds         if metabolites, reactions, genes and compartments
%                   should be sorted alphabetically by their identifier,
%                   otherwise they are kept in their original order
%                   (logical, default=false)
%
%   Usage: writeYaml(model,name,preserveQuotes,sortIds)
name=char(name);

if nargin < 3
    preserveQuotes = true;
end
if nargin < 4
    sortIds = false;
end
if ~endsWith(name,{'.yml','.yaml'})
    name = strcat(name,'.yml');
end

%Check that model is in RAVEN format:
if isfield(model,'rules')
    model = ravenCobraWrapper(model);
end

%Sort identifiers alphabetically
if sortIds == true
    model = sortIdentifiers(model);
end

%Simplify Miriam fields:
if isfield(model,'metMiriams')
    [model.newMetMiriams,model.newMetMiriamNames]   = extractMiriam(model.metMiriams);
end
if isfield(model,'rxnMiriams')
    [model.newRxnMiriams,model.newRxnMiriamNames]   = extractMiriam(model.rxnMiriams);
end
if isfield(model,'geneMiriams')
    [model.newGeneMiriams,model.newGeneMiriamNames] = extractMiriam(model.geneMiriams);
end
if isfield(model,'compMiriams')
    [model.newCompMiriams,model.newCompMiriamNames] = extractMiriam(model.compMiriams);
end

%Open file:
fid = fopen(name,'wt');
fprintf(fid,'---\n!!omap\n');

%Insert file header (metadata)
writeMetadata(model,fid);

%Metabolites:
fprintf(fid,'- metabolites:\n');
for i = 1:length(model.mets)
    fprintf(fid,'    - !!omap\n');
    writeField(model, fid, 'mets',        'txt', i, '  - id',          preserveQuotes)
    writeField(model, fid, 'metNames',    'txt', i, '  - name',        preserveQuotes)
    writeField(model, fid, 'metComps',    'txt', i, '  - compartment', preserveQuotes)
    writeField(model, fid, 'metFormulas', 'txt', i, '  - formula',     preserveQuotes)
    writeField(model, fid, 'metCharges',  'num', i, '  - charge',      preserveQuotes)
    writeField(model, fid, 'inchis',      'txt', i, '  - inchis',      preserveQuotes)
    writeField(model, fid, 'metMiriams',  'txt', i, '  - annotation',  preserveQuotes)
    writeField(model, fid, 'metFrom',     'txt', i, '  - metFrom',     preserveQuotes)
end

%Reactions:
fprintf(fid,'- reactions:\n');
for i = 1:length(model.rxns)
    fprintf(fid,'    - !!omap\n');
    writeField(model, fid, 'rxns',                 'txt', i, '  - id',                    preserveQuotes)
    writeField(model, fid, 'rxnNames',             'txt', i, '  - name',                  preserveQuotes)
    writeField(model, fid, 'S',                    'txt', i, '  - metabolites',           preserveQuotes)
    writeField(model, fid, 'lb',                   'num', i, '  - lower_bound',           preserveQuotes)
    writeField(model, fid, 'ub',                   'num', i, '  - upper_bound',           preserveQuotes)
    writeField(model, fid, 'grRules',              'txt', i, '  - gene_reaction_rule',    preserveQuotes)
    writeField(model, fid, 'rxnFrom',              'txt', i, '  - rxnFrom',               preserveQuotes)
    if model.c(i)~=0
        writeField(model, fid, 'c',                    'num', i, '  - objective_coefficient', preserveQuotes)    
    end
    writeField(model, fid, 'eccodes',              'txt', i, '  - eccodes',               preserveQuotes)
    writeField(model, fid, 'rxnReferences',        'txt', i, '  - references',            preserveQuotes)
    writeField(model, fid, 'subSystems',           'txt', i, '  - subsystem',             preserveQuotes)
    writeField(model, fid, 'rxnMiriams',           'txt', i, '  - annotation',            preserveQuotes)
    writeField(model, fid, 'rxnConfidenceScores',  'num', i, '  - confidence_score',      preserveQuotes)
end

%Genes:
fprintf(fid,'- genes:\n');
for i = 1:length(model.genes)
    fprintf(fid,'    - !!omap\n');
    writeField(model, fid, 'genes',          'txt', i, '  - id',         preserveQuotes)
    writeField(model, fid, 'geneShortNames', 'txt', i, '  - name',       preserveQuotes)
    writeField(model, fid, 'geneMiriams',    'txt', i, '  - annotation', preserveQuotes)
end

%Compartments:
fprintf(fid,'- compartments: !!omap\n');
for i = 1:length(model.comps)
    writeField(model, fid, 'compNames',   'txt', i, ['- ' model.comps{i}], preserveQuotes)
    writeField(model, fid, 'compMiriams', 'txt', i, '- annotation',             preserveQuotes)
end

%Close file:
fclose(fid);

end

function writeField(model,fid,fieldName,type,pos,name,preserveQuotes)
%Writes a new line in the yaml file if the field exists and the field is
%not empty at the correspoinding position. It's recursive for some fields
%(metMiriams, rxnMiriams, and S)

if isfield(model,fieldName)
    if strcmp(fieldName,'metComps')
        %metComps: write full name
        fieldName = 'comps';
        pos       = model.metComps(pos);
    end
    
    field = eval(['model.' fieldName]);
    
    if strcmp(fieldName,'metMiriams')
        if ~isempty(model.metMiriams{pos})
            fprintf(fid,['    ' name ': !!omap\n']);
            for i=1:size(model.newMetMiriams,2)
                %'i' represents the different miriam names, e.g.
                %kegg.compound or chebi
                if ~isempty(model.newMetMiriams{pos,i})
                    %As during the following writeField call the value of
                    %'i' would be lost, it is temporarily concatenated to
                    %'name' parameter, which will be edited later
                    writeField(model, fid, 'newMetMiriams', 'txt', pos, ['      - ' model.newMetMiriamNames{i} '_' num2str(i)], preserveQuotes)
                end
            end
        end
        
    elseif strcmp(fieldName,'rxnMiriams')
        if ~isempty(model.rxnMiriams{pos})
            fprintf(fid,['    ' name ': !!omap\n']);
            for i=1:size(model.newRxnMiriams,2)
                if ~isempty(model.newRxnMiriams{pos,i})
                    writeField(model, fid, 'newRxnMiriams', 'txt', pos, ['      - ' model.newRxnMiriamNames{i} '_' num2str(i)], preserveQuotes)
                end
            end
        end
        
    elseif strcmp(fieldName,'geneMiriams')
        if ~isempty(model.geneMiriams{pos})
            fprintf(fid,['    ' name ': !!omap\n']);
            for i=1:size(model.newGeneMiriams,2)
                if ~isempty(model.newGeneMiriams{pos,i})
                    writeField(model, fid, 'newGeneMiriams', 'txt', pos, ['      - ' model.newGeneMiriamNames{i} '_' num2str(i)], preserveQuotes)
                end
            end
        end
        
    elseif strcmp(fieldName,'compMiriams')
        if ~isempty(model.compMiriams{pos})
            fprintf(fid,['    ' name ': !!omap\n']);
            for i=1:size(model.newCompMiriams,2)
                if ~isempty(model.newCompMiriams{pos,i})
                    writeField(model, fid, 'newCompMiriams', 'txt', pos, ['      - ' model.newCompMiriamNames{i} '_' num2str(i)], preserveQuotes)
                end
            end
        end
        
    elseif strcmp(fieldName,'S')
        %S: create header & write each metabolite in a new line
        fprintf(fid,['    ' name ': !!omap\n']);
        if sum(field(:,pos) ~= 0) > 0
            model.mets   = model.mets(field(:,pos) ~= 0);
            model.coeffs = field(field(:,pos) ~= 0,pos);
            %Sort metabolites:
            [model.mets,order] = sort(model.mets);
            model.coeffs       = model.coeffs(order);
            for i = 1:length(model.mets)
                writeField(model, fid, 'coeffs',  'num', i, ['      - ' model.mets{i}], preserveQuotes)
            end
        end
        
    elseif sum(strcmp({'subSystems','newMetMiriams','newRxnMiriams','newGeneMiriams','newCompMiriams','eccodes'},fieldName)) > 0
        %eccodes/rxnNotes: if 1 write in 1 line, if more create header and list
        if strcmp(fieldName,'subSystems')
            list = field{pos};  %subSystems already comes in a cell array
        elseif strcmp(fieldName,'newMetMiriams')
            index = str2double(regexprep(name,'^.+_',''));
            name  = regexprep(name,'_\d+$','');
            list = strsplit(model.newMetMiriams{pos,index},'; ');
        elseif strcmp(fieldName,'newRxnMiriams')
            index = str2double(regexprep(name,'^.+_',''));
            name  = regexprep(name,'_\d+$','');
            list = strsplit(model.newRxnMiriams{pos,index},'; ');
        elseif strcmp(fieldName,'newGeneMiriams')
            index = str2double(regexprep(name,'^.+_',''));
            name  = regexprep(name,'_\d+$','');
            list = strsplit(model.newGeneMiriams{pos,index},'; ');
        elseif strcmp(fieldName,'newCompMiriams')
            index = str2double(regexprep(name,'^.+_',''));
            name  = regexprep(name,'_\d+$','');
            list = strsplit(model.newCompMiriams{pos,index},'; ');
        else
            list = strrep(field{pos},' ','');     %Exception for eccodes
            list = strsplit(list,';');
        end

        if length(list) == 1 && ~strcmp(list{1},'') && ~strcmp(fieldName,'subSystems')
            if preserveQuotes
                list = strcat('"',list,'"');
            end
            fprintf(fid,['    ' name ': ' list{1} '\n']);
        elseif length(list) > 1 || strcmp(fieldName,'subSystems')
            if preserveQuotes
                list = strcat('"',list,'"');
            end
            fprintf(fid,['    ' name ':\n']);
            for i = 1:length(list)
                fprintf(fid,[regexprep(name,'(^\s*).*','$1') '        - ' list{i} '\n']);
            end
        end
        
    elseif sum(pos) > 0
        %All other fields:
        if strcmp(type,'txt')
            value = field{pos};
            if preserveQuotes && ~isempty(value)
                value = strcat('"',value,'"');
            end
        elseif strcmp(type,'num')
            if isnan(field(pos))
                value = [];
            else
                value = num2str(field(pos),12);
            end
        end
        if ~isempty(value)
            fprintf(fid,['    ' name ': ' value '\n']);
        end
    end
end


end

function writeMetadata(model,fid)
% Writes model metadata to the yaml file. This information will eventually
% be extracted entirely from the model, but for now, many of the entries
% are hard-coded defaults for HumanGEM.

fprintf(fid, '- metaData:\n');
fprintf(fid, ['    id: "',          model.id,          '"\n']);
fprintf(fid, ['    name: "',        model.name, '"\n']);
if isfield(model,'version')
    fprintf(fid, ['    version: "', model.version,     '"\n']);
end
fprintf(fid, ['    date: "',        datestr(now,29),   '"\n']);  % 29=YYYY-MM-DD
if isfield(model,'annotation')
    if isfield(model.annotation,'defaultLB')
        fprintf(fid, ['    defaultLB: "',    num2str(model.annotation.defaultLB), '"\n']);
    end
    if isfield(model.annotation,'defaultUB')
        fprintf(fid, ['    defaultUB: "',    num2str(model.annotation.defaultUB), '"\n']);
    end
    if isfield(model.annotation,'givenName')
        fprintf(fid, ['    givenName: "',    model.annotation.givenName,          '"\n']);
    end
    if isfield(model.annotation,'familyName')
        fprintf(fid, ['    familyName: "',   model.annotation.familyName,         '"\n']);
    end
    if isfield(model.annotation,'authors')
        fprintf(fid, ['    authors: "',      model.annotation.authors,            '"\n']);
    end
    if isfield(model.annotation,'email')
        fprintf(fid, ['    email: "',        model.annotation.email,              '"\n']);
    end
    if isfield(model.annotation,'organization')
        fprintf(fid, ['    organization: "', model.annotation.organization,       '"\n']);
    end
    if isfield(model.annotation,'taxonomy')
        fprintf(fid, ['    taxonomy: "',     model.annotation.taxonomy,           '"\n']);
    end
    if isfield(model.annotation,'note')
        fprintf(fid, ['    note: "',         model.annotation.note,               '"\n']);
    end
    if isfield(model.annotation,'sourceUrl')
        fprintf(fid, ['    sourceUrl: "',    model.annotation.sourceUrl,          '"\n']);
    end
end
end
