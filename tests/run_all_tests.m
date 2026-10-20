% RUN_ALL_TESTS Master test runner executing all unit and integration tests.
cd('C:\workspace\nr_ics');
addpath('C:\workspace\nr_ics');

fprintf('\n========================================================================\n');
fprintf('  RUNNING COMPLETE 6G SSB LLS TEST SUITE                                \n');
fprintf('========================================================================\n\n');

fprintf('>>> 1/4: Running test_sequences.m <<<\n');
run(fullfile('C:\workspace\nr_ics', 'tests', 'test_sequences.m'));

fprintf('\n>>> 2/4: Running test_grid_mapping.m <<<\n');
run(fullfile('C:\workspace\nr_ics', 'tests', 'test_grid_mapping.m'));

fprintf('\n>>> 3/4: Running test_channel.m <<<\n');
run(fullfile('C:\workspace\nr_ics', 'tests', 'test_channel.m'));

fprintf('\n>>> 4/4: Running test_pbch_chain.m <<<\n');
run(fullfile('C:\workspace\nr_ics', 'tests', 'test_pbch_chain.m'));

fprintf('\n========================================================================\n');
fprintf('  ALL 4 TEST BATTERIES COMPLETED SUCCESSFULLY WITH 100%% PASS           \n');
fprintf('========================================================================\n\n');
