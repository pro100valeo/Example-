////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//   Company:   AO OKTB Omega                                                 //
//                                                                            //
//   Division:  otd 21                                                        //
//                                                                            //
//   Design:    СПНС-3                                                        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//   Name:      sata_platform                                         		  //
//                                                                            //
//   Autor:     Valentin Zharkov                                              //
//                                                                            //
//   Email:     pro100valeo@gmail.com                                         //
//                                                                            //
//   Date:      25.11.2020                                                    //
//                                                                            //
//   HDL:       SystemVerilog-IEEE Std 1800-2012                              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//      Copyright (C) 2020 Zharkov Valentin     pro100valeo@gmail.com         //
//                                                                            //
//   This  source  file  may be used and  distributed  without restriction    //
//   provided that this copyright statement  is  not removed from the file    //
//   and that any derivative work contains  the original  copyright notice    //
//   and the associated disclaimer.                                           //
//                                                                            //
//   THIS  SOFTWARE  IS  PROVIDED AS IS AND WITHOUT ANY EXPRESS OR IMPLIED    //
//   WARRANTIES, INCLUDING, BUT  NOT  LIMITED  TO, THE  IMPLIED WARRANTIES    //
//   OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.                 //
//   IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,   //
//   INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL DAMAGES    //
//   (INCLUDING, BUT  NOT  LIMITED  TO, PROCUREMENT OF SUBSTITUTE GOODS OR    //
//   SERVICES; LOSS  OF  USE, DATA, OR  PROFITS; OR BUSINESS INTERRUPTION)    //
//   HOWEVER  CAUSED  AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,    //
//   STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING    //
//   IN  ANY  WAY OUT  OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE    //
//   POSSIBILITY OF SUCH DAMAGE.                                              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Данный модуль (полностью зависит от oob_controller) является прослойкой между oob_controller (принадлежащему sata_stack) и гигабитным трансивером.
// sata_platform принимает/посылает примитивы для установки соединения, послылает служебные сигналы, за счет которых ведется управление автоматом oob_controller
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//`define SATA_PLATFORM_TO_FULL_SATA_PROJECT // если не закоменчено, то sata platform включается в полный проект, где ожидается модуль гигабитного трансивера
`define TEST_PLATFORM_WITHOUT_TRANSIEVER // если не закоменчено, то sata platform тестируется без трансивера, исключительно за счет testbench

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    module sata_platform
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#(
	// K(28.5) simbol = 8'b01001010 
)

(
	input   logic                  		clk,                // Clock
	input   logic                  		rst,                // Asynchronous reset active high

	//  сигналы с оболочки (вынести их отсюда)
	input 	logic 						platform_error, 	// as reset from oob && сигнал не готовности платформы
	input 	logic 						linkup, 			// сигнал выведенный с сата стека по нему можно отключать ob_tx_rx по идее
	output 	logic 						o_platform_ready, 	// платформа готова к работе

	// сигналы для эмуляции работы трансивера (исключительно для теста)
	`ifdef TEST_PLATFORM_WITHOUT_TRANSIEVER
	//input 	logic 						clk_from_transmiter,// частота на которойт ALT_GX приемник выдает принятые данные  
	input 	logic 						rx_signaldetect, 	// Сигнал с гигабитного трансивера (rx_signaldetect == 0 - RX линия SATA нашего HOST'а в третьем состоянии)
	input 	logic 	[1:0] 	 			rx_cntrldetect, 	// Сигнал с гигабитного трансивера подсвечивающий какое из двух полученных слов является К символом ("запятой")
	output 	logic 						tx_forceelecidle, 	// Cигнал к гигабитному трансиверу отвечающий за перевод линии TX (SATA) в третье состояние

	input 	logic 	[15:0] 				i_rx_data, 			// даннные с гигабитного трансивера принятые по SATA и декодированные трансивером
	output 	logic 	[15:0] 				o_tx_data, 			// 16и битные данные от платформы к гигабитному трансиверу

	input 	logic 						rx_clk_transiever, 	// clock по которому gigabite transiever принимает данные дя передачи
	input 	logic 						tx_clk_transiever, 	// clock по которому gigabite transiever выдает данные принятые по SATA
	`endif

	// сигналы платформы
	input 	logic 	[31:0] 				i_tx_data, 			// 32х битные данные со стека для передачи по SATA
	output 	logic 	[31:0] 				o_rx_data, 			// данные от платформы, которые приняты по SATA и собраны уже в 32 битную шину

	input 	logic 	[3:0] 				oob_state, 			// состояние oob (тот, что в составе sata_stack) 

	input 	logic 						i_tx_reset, 		// запрос на отправку примитива  (comreset) cominit
	input 	logic 						i_tx_wake, 			// запрос на отправку примитива  (comwake)
	input 	logic 						i_tx_align, 		// tx_is_k (по идее запрос на отправку "запятая" )
	input 	logic 						i_set_elec_idle, 	// сигнал (от sata_stack) отвечающий за перевод шины в третье состояние !!!!!!!!! странно написан

	output 	logic 	[3:0] 				o_rx_is_k, 			// принят примитив align ( получена "запяиая") rx_is_k
	output 	logic 						o_rx_elec_idle, 	// шина в третьем состоянии (сигнал не нужен тк в oob не использует его) 
	output 	logic 						o_rx_init, 			// принят примитив cominit
	output 	logic 						o_rx_wake, 			// принят примитив comwake
	output 	logic 						o_tx_oob_complite, 	// Platform are finished with this OOB transaction

	output 	logic 						o_rx_byte_aligned 	// принятые данные выровнены правильно ( нужно написать эту часть)

);


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Local Variable
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	logic 								cnt_from_fifo; 		// счетчик для формирования pseudo fifo данных поступающих с трансивера
	logic 								cnt_to_fifo; 		// счетчик для формирования pseudo fifo данных поступающих с трансивера
	logic 	[15:0] 						reciev_first_dword; // первые 16 бит из 32х принятые по SATA
	logic 	[1:0] 						cnt_double_strob; 	// счетчик для удваивания длины транслируемых из модуля стробов
	logic 								shift_reg; 			// индикатор смены состояний платформы
	logic 	[1:0] 						shift_rx_clk; 		// сдвиговый регистр для опредеоения положительного фронта rx_clk (of fifo gigabite transiever)
	logic 	[1:0] 						shift_tx_clk; 		// сдвиговый регистр для опредеоения положительного фронта tx_clk (of fifo gigabite transiever)

    `ifdef SATA_PLATFORM_TO_FULL_SATA_PROJECT
    	logic 							rx_signaldetect; 	// Сигнал с гигабитного трансивера (rx_signaldetect == 0 - RX линия SATA нашего HOST'а в третьем состоянии)
    	logic 							tx_forceelecidle; 	// Cигнал к гигабитному трансиверу отвечающий за перевод линии TX (SATA) в третье состояние
    	logic [1:0] 	 				rx_cntrldetect, 	// Сигнал с гигабитного трансивера подсвечивающий какое из двух полученных слов является К символом ("запятой")
    	logic [15:0] 					i_rx_data; 			// даннные с гигабитного трансивера принятые по SATA и декодированные трансивером
    	//logic [31:0] 					o_rx_data; 			// данные от платформы, которые приняты по SATA и собраны уже в 32 битную шину

		logic [15:0] 					o_tx_data, 			// 16и битные данные от платформы к гигабитному трансиверу

		logic 							rx_clk_transiever, 	// clock по которому gigabite transiever принимает данные дя передачи
		logic 							tx_clk_transiever, 	// clock по которому gigabite transiever выдает данные принятые по SATA

		logic [16:0] 					reconfig_fromgxb, 	// данные для управления подстройкой частоты
		logic [3:0] 					reconfig_togxb, 	// данные с блока подстройки частоты
    `endif

    // сигналы, связанные с приемником примитивов
    logic 								search_cominit; 	// запроис на поиск примитива COMINIT
    logic 								search_comwake; 	// запроис на поиск примитива COMWAKE

    logic 								cominit_ok; 		// примитив COMINIT распознан
    logic 								comwake_ok; 		// примитив COMWAKE распознан

    logic 								no_cominit_ok; 		// SSD окончил передачу примитива COMINIT
    logic 								no_comwake_ok; 		// SSD окончил передачу примитива COMWAKE

    logic 								rx_busy; 			// Приемник занят исполнением команды
    logic 								reset_rx; 			// сброс приемника паттернов OOB

    // сигналы, связанные с передатчиком примитивовв
    logic 								transmiter_busy; 	// передатчик примитивов занят исполнением команды
    logic 								send_comreset; 		// команда на отправку пакета примитивов COMRESET
    logic 								send_comwake; 		// команда на отправку пакета примитивов COMWAKE

    logic 								tx_busy; 			// передатчик занят передачей примитива
    logic 								reset_tx; 			// сброс генератора паттернов
    logic 								oob_tx_forceelecidle; // сигнал с передатчика oob паттернов отвечающий за перевод линии TX Host в третье состояние

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Подсветка состояния oob для теста
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    typedef enum logic [3:0]{
 		IDLE                    = 4'h0,
 		SEND_RESET              = 4'h1, // отправление примитива COMRESET
 		WAIT_FOR_INIT           = 4'h2, // прием примитива COMINIT
 		WAIT_FOR_NO_INIT        = 4'h3, // ожидание окончания передачи COMINIT от SSD
 		WAIT_FOR_CONFIGURE_END  = 4'h4, // состояние подстройки (наверное пропущу)
 		SEND_WAKE               = 4'h5, // отправление примитива COMWAKE
 		WAIT_FOR_WAKE           = 4'h6, // прием примитива COMWAKE
 		WAIT_FOR_NO_WAKE        = 4'h7, // ожидание окончания передачи COMWAKE от SSD
 		WAIT_FOR_IDLE           = 4'h8, // не используется !!
 		WAIT_FOR_ALIGN          = 4'h9, // ожидание ALIGN от SSD
 		SEND_ALIGN              = 4'hA, // отправление ответного ALIGN
 		DETECT_SYNC             = 4'hB,
 		READY                   = 4'hC
    } oob_state_view;
    oob_state_view platform_curr_state, platform_next_state;

	always_ff @(posedge clk)
	begin 
		platform_curr_state <= platform_next_state; // из интереса поставить блокирующее присваивание
	end

	always_comb
	begin 
		if (rst || oob_state == IDLE || platform_error) platform_next_state = IDLE;
		else case (platform_next_state)
			IDLE: 						platform_next_state = (i_tx_reset) 		? SEND_RESET 				: IDLE;
			SEND_RESET: 				platform_next_state = (!tx_busy) 		? WAIT_FOR_INIT 			: SEND_RESET;
			WAIT_FOR_INIT: 				platform_next_state = (cominit_ok) 		? WAIT_FOR_NO_INIT 			: WAIT_FOR_INIT;
			WAIT_FOR_NO_INIT: 			platform_next_state = (no_cominit_ok)	? WAIT_FOR_CONFIGURE_END 	: WAIT_FOR_NO_INIT;
			WAIT_FOR_CONFIGURE_END: 	platform_next_state = (i_tx_wake) 		? SEND_WAKE 				: WAIT_FOR_CONFIGURE_END;
			SEND_WAKE: 					platform_next_state = (!tx_busy) 		? WAIT_FOR_WAKE 			: SEND_WAKE;
			WAIT_FOR_WAKE: 				platform_next_state = (comwake_ok) 		? WAIT_FOR_NO_WAKE 			: WAIT_FOR_WAKE;
			WAIT_FOR_NO_WAKE: 			platform_next_state = (no_comwake_ok)	? WAIT_FOR_ALIGN 			: WAIT_FOR_NO_WAKE;
			WAIT_FOR_ALIGN: 			platform_next_state = (align_detect) 	? SEND_ALIGN 				: WAIT_FOR_ALIGN;
			SEND_ALIGN: 				platform_next_state = (!tx_busy) 		? READY 					: SEND_ALIGN;
			READY: 						platform_next_state = (cominit_ok) 		? IDLE 						: READY;
			default: 					platform_next_state = IDLE;
		endcase
	end
    
    // индикация смены состояний
	assign shift_reg = (arbiter_next_state != arbiter_curr_state) ? '1 : '0;

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//  Подключение приемника и передатчика oob примитивов (возможно стоит вытащить параметры oob_rx, oob_tx сюда)
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	oob_rx oob_reciever(
	 	.clk 				(clk 				), // Clock
	 	.rst 				(rst || reset_rx 	), // reset
	 	.rx_signaldetect 	(rx_signaldetect 	), // Гигабитный трансивер обнаружил сигнал 
	 	.i_search_cominit 	(search_cominit 	), // запрос на поиск cominit
	 	.i_search_comwake 	(search_comwake 	), // запрос на поиск comwake
	 	.o_cominit_ok  		(cominit_ok 		), // cominit обнаружен
	 	.o_comwake_ok  		(comwake_ok 		), // comwake обнаружен
	 	.o_no_cominit_ok 	(no_cominit_ok 		), // SSD закончил передачу cominit
	 	.o_no_comwake_ok 	(no_comwake_ok 		), // SSD закончил передачу comwake
	 	.o_busy 			(rx_busy 			)  // индикация занятости модуля
	);

	oob_tx oob_transmiter(
		.clk 				(clk 				), 	// Clock
		.rst 				(rst || reset_tx	), 	// reset
		.comreset 			(send_comreset 		), 	// Запрос на передачу паттерна comreset
		.comwake 			(send_comwake 		), 	// Запрос на передачу паттерна comwake
		.busy 				(tx_busy 			), 	// Если "1" - выполняется передача паттерна
		.tx_forceelecidle 	(oob_tx_forceelecidle 	) 	// сигнал к гигабитному трансиверу (отвечает за управлением выходной линии SATA, перевод ее в третье состояние)
	);

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Подключение гигабитного трансивера
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	`ifdef SATA_PLATFORM_TO_FULL_SATA_PROJECT
	alt_gx altera_gigabite_transiever(
		.rx_signaldetect 	(rx_signaldetect 	), 	// Сигнал с гигабитного трансивера (rx_signaldetect == 0 - RX линия SATA нашего HOST'а в третьем состоянии)
    	.tx_forceelecidle 	(tx_forceelecidle 	), 	// Cигнал к гигабитному трансиверу отвечающий за перевод линии TX (SATA) в третье состояние
    	.rx_dataout 		(i_rx_data 			),	// даннные с гигабитного трансивера принятые по SATA и декодированные трансивером
    	.tx_datatin 		(o_tx_data 			), 	// 16и битные данные от платформы к гигабитному трансиверу
 
		.rx_clkout 			(rx_clk_transiever 	), 	// clock по которому gigabite transiever принимает данные дя передачи
		.tx_clkout 			(tx_clk_transiever 	), 	// clock по которому gigabite transiever выдает данные принятые по SATA

		.reconfig_fromgxb 	(reconfig_fromgxb 	), 	// данные к блоку alt_gx_reconf для управления подстройкой частоты
		.reconfig_togxb 	(reconfig_togxb 	),
	);

	alt_gx_reconf altera_block_reconfig_frequency(

	);
	`endif

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// PSEUDO FIFO для согласования разрядонсти шин данных
// тк sata_stack расчитан по 32 битную шину данных, а гигабитный трансивер на 16 бит
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	// счетчике тактов clk от трансивера, нужен для оперделения первых и вторых 16 бит в принимаемом слове 
	always_ff @(posedge clk)
	begin 
		if (rst) 									cnt_from_fifo <= '0;
		else case (platform_curr_state)
			WAIT_FOR_ALIGN,
			READY: 									cnt_from_fifo <= cnt_from_fifo + 1;
			default: 								cnt_from_fifo <= '0;
		endcase 
	end

	// счетчике тактов clk к трансиверу, нужен для передачи данных от стека к трансиверу
	always_ff @(posedge clk)
	begin 
		if (rst) 									cnt_to_fifo <= '0;
		else case (platform_curr_state)
			SEND_ALIGN,
			READY: 									cnt_to_fifo <= cnt_to_fifo + 1;
			default: 								cnt_to_fifo <= '0;
		endcase 
	end

	// 32 битные данные принятые с трансивера, для отдачи их sata_stack
	always_ff @(posedge clk)
	begin 
		case (platform_curr_state)
			WAIT_FOR_ALIGN,
			READY: 		if (cnt_from_fifo == 0) 	o_rx_data <= '0;
						else 					
							begin 
													o_rx_data [15:0] 	<= reciev_first_dword;
													o_rx_data [31:16] 	<= i_rx_data; 
							end
			default: 								o_rx_data 			<= '0;
		endcase
	end

	// данные к гигабитному трансиверу
	always_ff @(posedge clk)
	begin 
		case (platform_curr_state)
			WAIT_FOR_ALIGN,
			SEND_ALIGN,
			READY: 		if (cnt_to_fifo == 0) 		o_tx_data <= i_tx_data [15:0];
						else 						o_tx_data <= i_tx_data [31:16]; 		
			default: 								o_tx_data <= '0;
		endcase
	end

	// "запоминаем" из двух DWORSD принятых по SATA
	always_comb
	begin 
		case (platform_curr_state)
			WAIT_FOR_ALIGN,
			READY: 									reciev_first_dword = (cnt_from_fifo == '0) ? i_rx_data : reciev_first_dword; 
			default: 								reciev_first_dword = '0;
		endcase
	end

	// подсветка К символа (запятой)
	always_comb 
	begin : proc_o_rx_is_k
		if (rst || platform_curr_state != (WAIT_FOR_ALIGN || READY || SEND_ALIGN) ) o_rx_is_k = '0;
		case (cnt_from_fifo)
			0: 																		o_rx_is_k [1:0] = rx_cntrldetect;
			1: 																		o_rx_is_k [3:2] = rx_cntrldetect;
			default: 																o_rx_is_k = '0;
		endcase
	end

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Запросы на поиск и передачу последовательностей
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	// signals to oob_rx
	assign search_cominit = (platform_next_state == WAIT_FOR_INIT && shift_reg) 	? '1 : '0; 
	assign search_comwake = (platform_next_state == WAIT_FOR_WAKE && shift_reg) 	? '1 : '0;

	// signals to oob_tx
	assign send_comreset = (i_tx_reset) ? '1 : '0;
	assign send_comwake  = (i_tx_wake)  ? '1 : '0;

	// align 

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Служебные сигналы для oob_controller (возможно стоит увеличить длительность, тк oob_controller работает на 75МГц, а platform на 150МГц)
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	// платформа готова к работе (если сигнал в нуле, oob_controller не начнет работать)
	assign o_platform_ready = (!rst && !platform_error) ? '1 : '0;

	// сигнал говорящий о том, что обнаружен примитив COMINIT (длительность увеличена за счет зависания данного сигнала в 1 до сброса модуля в initial state или распознования окончания переждачи  cominit от ssd)
	always_comb
	begin 
		if (rst || platform_curr_state != (WAIT_FOR_INIT || WAIT_FOR_NO_INIT) ) 	o_rx_init = '0;
		else case (o_rx_init)
			0: 			o_rx_init = (cominit_ok) 		? '1 : '0;
			1: 			o_rx_init = (!no_cominit_ok) 	? '1 : '0; 
			default: 	o_rx_init = '0;
		endcase
	end

	// сигнал говорящий о том, что обнаружен примитив COMWAKE (длительность увеличена за счет зависания данного сигнала в 1 до сброса модуля в initial state или распознования окончания переждачи  comwake от ssd)
	always_comb
	begin 
		if (rst || platform_curr_state != (WAIT_FOR_WAKE || WAIT_FOR_NO_WAKE) ) 	o_rx_wake = '0;
		else case (o_rx_wake)
			0:			o_rx_wake = (comwake_ok) 		? '1 : '0;
			1: 			o_rx_wake = (!no_comwake_ok) 	? '1 : '0; // в oob_controller он ждет 0  на этом сигнале чтобы увидеть отсутсвие передачи паттернов от SSD
			default: 	o_rx_wake = '0;
		endcase
	end

	// счетчик, необходимый для удваивания транслируемых стробов (во времени)
	always_ff @(posedge clk)
	begin 
		if (rst) 		cnt_double_strob <= '0;
		else case (cnt_double_strob)
			2'b00: 		cnt_double_strob <= (o_tx_oob_complite) ? 2'b01 : '0;
			2'b01: 		cnt_double_strob <= 2'b11;
			2'b11: 		cnt_double_strob <= '0;
			default: 	cnt_double_strob <= '0;
		endcase
	end

	// внеполосная последовательнасть завершена (строб удваивается для согласование работы platformы (150Мгц) и oob-controller (75МГц))
	always_comb
	begin 
		if (rst || platform_curr_state == IDLE) 	o_tx_oob_complite <= '0;
		else case (o_tx_oob_complite)
			0: 										o_tx_oob_complite = (
														(no_cominit_ok 									) || 
														(platform_curr_state == SEND_RESET && !tx_busy 	) ||
														(platform_curr_state == SEND_WAKE  && !tx_busy 	) 
													) 														? '1 : '0;
			1:										o_tx_oob_complite = (cnt_double_strob == 2'b11) 		? '1 : '0;
			default: 								o_tx_oob_complite = '0;
		endcase
	end

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Установка наличия/отсутсвия сигнала на линии TX Host 
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	always_comb 
	begin : proc_tx_forceelecidle
		case (platform_curr_state)
			SEND_RESET,
			SEND_WAKE: 				tx_forceelecidle = oob_tx_forceelecidle;
			WAIT_FOR_CONFIGURE_END,
			WAIT_FOR_WAKE,           
 			WAIT_FOR_NO_WAKE,        
 			WAIT_FOR_IDLE,           
 			WAIT_FOR_ALIGN,          
 			SEND_ALIGN,              
 			DETECT_SYNC,             
 			READY: 					tx_forceelecidle = '0;                   
			default: 				tx_forceelecidle = '1;
		endcase
	end

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    endmodule
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// HOST TX:--|RESET|----|WAKE|-----|d10.2|-------|

// HOST RX:--|----|INIT|-----|WAKE|2048 ALIGN(0)|


//--------------------------------------------------------------------------------------------------------------------------------------------------------------
// 														Процедура установки соединения за которую отвечает арбитр
//--------------------------------------------------------------------------------------------------------------------------------------------------------------
//1. Хост выдает последовательность COMRESET.
//--------------------------------------------------------------------------------------------------------------------------------------------------------------
//2. Когда устройство (SSD) обнаруживает последовательность COMRESET, оно отвечает COMINIT.
//--------------------------------------------------------------------------------------------------------------------------------------------------------------
//3. Хост калибрует и выдает последовательность COMWAKE. (калибровку я пропускаю)
//--------------------------------------------------------------------------------------------------------------------------------------------------------------
//4. Устройство (SSD) отвечает - устройство обнаруживает последовательность COMWAKE на своей паре RX и калибрует ее и передатчик (необязательно). 
//   После калибровки SSD отправляет последовательность COMWAKE из шести пакетов,
//   а затем отправляет непрерывный поток последовательности ALIGN, начиная с самой высокой из поддерживаемых SSD скопростей.
//   После отправки ALIGN DWORD в течение 54,6 мкс (2048 номинальных значений Gen1 DWORD) без ответа от хоста, накопитель предполагает,  
//   что хост не может общаться на этой скорости. Если доступны дополнительные скорости, устройство пробует следующую более низкую поддерживаемую скорость, 
//   отправляя ALIGN DWORD с этой скоростью на 54,6 мкс (2048 номинальных значений DWORD Gen1). Этот шаг повторяется для всех поддерживаемых скоростей. 
//   После достижения самой низкой скорости без ответа от хоста устройство перейдет в состояние ошибки.
//--------------------------------------------------------------------------------------------------------------------------------------------------------------
//5. После обнаружения последовательности COMWAKE хост (TX - line) начинает передавать символы d10.2. с самой низкой из поддерживаемых скоростей.
//   В свою очередь RX - line находится в поиске ALIGN последовательности, причем обнаружив ALIGN последовательность, хост должен вернуть ее с той же скростью,
//   что и получил. Хост должен быть спроектирован таким образом, чтобы он мог получить калибровку за 54,6 мс(2048 номинальных значений Gen1 DWORD) с любой 
//   заданной скоростью. Хост должен обеспечивать не менее 873,8мкс (32768 Gen1 DWORD) после обнаружения COMWAKE для получения первoго ALIGN.
//   Этот интервал обеспечивает взаимодействие с синхронными устройствами разных поколений (возможно, перевел неверно).
//   Если ALIGN не получен в интервале времени 873,8мкс (32768 Gen1 DWORD), Хост перезапускает процесс инициализации, повтторная ингициализация будет происходить,
//   пока не будет произведен сброс вышестоящими модулями. 
//--------------------------------------------------------------------------------------------------------------------------------------------------------------
//6. Блокировка устройства - устройство блокируется в соответствии с последовательностью ALIGN и, когда готово, отправляет SYNC.
//   примитив, означающий, что он готов к нормальной работе.
//--------------------------------------------------------------------------------------------------------------------------------------------------------------
//7. После получения трех последовательных примитивов non-ALIGN устанавливается канал связи и может начаться нормальная работа.
//--------------------------------------------------------------------------------------------------------------------------------------------------------------




//-------------------------------------------------------------------------------------------------------------------------------------------------------------
//  												Напоминалка таймингов (HOST в роли приемника)
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// AWAIT ALIGN TIMEOUT: 
// Со стороны HOST: если HOST не обнаружил ALIGN за период времени равный 873.8мкс, он обязан прервать установку соединения и по необходимости попробовать заного.
// Со стороны SSD: если SSD не обнаружилл ответный AlIGN за 873.8мкс, установка соединения не прошла, SSD сваливается в состаяние  ожидания RESET.
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// AWAIT COMWAKE TIMEOUNT: 
// Со стороны HOST: 533нс - это время которое SSD может подождать до начала отправления HOST'OM сиволов D10.2 
// СО стороны SSD:
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// 

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// 													Напоминалка таймингов (HOST в роли передатчика)
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// После передачи COMWAKE HOST не может удерживать интерфейс в неактивном состоянии более 228.3 нс
//-------------------------------------------------------------------------------------------------------------------------------------------------------------




//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// 																Оригинал текста
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
1. 	Host/device are powered and operating normally with some form of active communication.
2. 	Some condition in the host causes the host to issue COMRESET
3. 	Host releases COMRESET. Once the condition causing the COMRESET is released, the host releases the COMRESET signal and puts the bus in a quiescent condition.
4. 	Device issues COMINIT – When the device detects the release of COMRESET, it responds with a COMINIT. This is also the entry point if the device is late starting. 
	The device may initiate communications at any time by issuing a COMINIT.
5. 	Host calibrates and issues a COMWAKE.
6. 	Device responds – The device detects the COMWAKE signal on its RX pair and calibrates its transmitter (optional). Following calibration, 
	the device sends a six burst COMWAKE signal and then sends a continuous stream of the ALIGN sequence. After 2048 ALIGN Dwords have been sent without response 
	from the host as determined by detection of ALIGN primitives received from the host, the device may assume that the host cannot communicate at that speed. 
	If additional legacy speeds are available, the device will try the next fastest speed by sending 2048 ALIGN dwords at that rate. 
	This step is repeated for as many legacy speeds are supported. Once the lowest speed has been reached without response from the host, the device will enter an error state.
7. 	Host locks – after detecting the COMWAKE, the host starts transmitting D10.2 characters (see 6.7.6) at its lowest supported rate. 
	Meanwhile, the host receiver locks to the ALIGN sequence and, when ready, returns the ALIGN sequence to the device at the same speed as received. 
	A host must be designed such that it can acquire lock given 2048 ALIGN Dwords. 
	The host should allow for at least 32768 Gen1 dwords (880us) after detecting the release of COMWAKE to receive the first ALIGN. 
	This will ensure interoperability with multi-generational and synchronous devices. If no ALIGN is received within 32768 Gen1 dwords (880us), 
	the host shall restart the power-on sequence – repeating indefinitely until told to stop by the application layer.
8. 	Device locks – the device locks to the ALIGN sequence and, when ready, sends the SYNC primitive indicating it is ready to start normal operation.
9. 	Upon receipt of three back-to-back non-ALIGN primitives, the communication link is established and normal operation may begin.
*/