requires 'parent', 0;
requires 'Future', '>= 0.30';
requires 'Tickit::Widget', 0;
requires 'Tickit::Widget::Table', '>= 0.210';
requires 'Log::Any', 0;
requires 'Variable::Disposition', 0;
requires 'Adapter::Async', 0;

on 'test' => sub {
	requires 'Test::More', '>= 0.98';
	requires 'Test::Fatal', '>= 0.010';
	requires 'Test::Refcount', '>= 0.07';
};

