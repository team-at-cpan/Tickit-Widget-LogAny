requires 'parent', 0;
requires 'Future', '>= 0.30';
requires 'Text::Wrap', 0;
requires 'Tickit::Widget', 0;
requires 'Tickit::Widget::Table', '>= 0.210';
requires 'Tickit::Widget::VBox', 0;
requires 'Tickit::Widget::Static', 0;
requires 'Tickit::Widget::Frame', 0;
requires 'Tickit::Widget::Button', 0;
requires 'Log::Any', 0;
requires 'Variable::Disposition', 0;
requires 'Adapter::Async', 0;

on 'test' => sub {
	requires 'Test::More', '>= 0.98';
	requires 'Test::Fatal', '>= 0.010';
	requires 'Test::Refcount', '>= 0.07';
};

