package gui_window::stop_words::stemming_nl;

use strict;
use base qw(gui_window::stop_words);





#--------------#
#   �A�N�Z�T   #

sub method{
	return 'stemming';
}

sub method_name{
	return 'Snowball Stemming';
}

sub locale_name{
	return 'nl';
}

sub win_name{
	return 'w_stopwords_stteming_nl';
}
1;