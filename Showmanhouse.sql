create database ShowmanHouse
use ShowmanHouse
---Creating Schema Events
create schema Events
go
---Creating schema HumanResources
create schema HumanResources
go
---Creating schema Management
create schema Management
go
---Creating Table Events.Customers
create Table Events.Customers(
CustomerID int identity(1,1) Primary key,
Name varchar(50) not null,
Address varchar(100) not null,
City varchar(50) not null,
State varchar(50) not null,
Phone varchar(100) not null check (Phone like '[0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9]')
)
go 

---Creating Table Events.EventTypes
create table Events.EventTypes(
EventTypeId int identity(1,1) Primary key,
Description varchar(100) not null,
ChargePerPerson money not null check(ChargePerPerson > 0)
)
go


---Creating Table HumanResources.Employees
create table HumanResources.Employees(
EmployeeId int identity(1,1) Primary key,
FirstName varchar(20) not null,
LastName varchar(20) not null,
Address varchar(100) not null,
Phone varchar(100) not null check(Phone like '[0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9]'),
Title varchar(50) not null constraint chkTitle check(Title in('Executive', 'Senior Executive', 'Management Trainee', 'Event Manager', 'Senior Event Manager'))
)
go


---Creating Table Management.Events
create table Management.Events(
EventId int identity(1,1) Primary Key,
EventName varchar(50) not null,
StartDate datetime  not null check (StartDate > getdate()),
EndDate datetime not null check (EndDate > getdate()),
Location varchar(100) not null,
NoOfPeople int not null check(NoOfPeople >= 50),
StaffRequired int not null check(StaffRequired > 0),
EventTypeId int not null Foreign Key References Events.EventTypes(EventTypeId),
CustomerId int not null Foreign Key References Events.Customers(CustomerId),
EmployeeId int not null Foreign Key References HumanResources.Employees(EmployeeId),
Constraint chkDate check (StartDate < EndDate))
go

---Creating Table Management.PaymentMethods
create table Management.PaymentMethods(
PaymentMethodId int identity(1,1) Primary key,
Description varchar(20) check(Description in ('cash', 'cheque','credit card'))
)
go

---Creating Table Management.Payment
create table Management.Payment(
PaymentId int identity(1,1) Primary key,
EventId int Foreign key References Management.Events(EventId),
PaymentDate datetime not null check(PaymentDate > getdate()),
PaymentMethodId int not null Foreign key References Management.PaymentMethods(PaymentMethodId),
PaymentAmount money not null,
ChequeNo int default '',
CreditCardNo int default '',
CardHoldersName varchar(50) default '',
CreditCardExpiryDate datetime check(CreditCardExpiryDate > getdate()),
Balance money,
)
go

---Creating Table Management.PaymentStatus
create table Management.PaymentStatus(
PaymentStatusId int identity(1,1),
AmountPaid money not null,
Balance money,
Status varchar(10),
PaymentId int Foreign key References Management.Payment(PaymentId)
)
go

---Creating Trigger to calculate the PaymentAmount in table Management.Payment
create trigger PaymentAmounts on Management.Payment
instead of insert as 
declare @PaymentAmount money
declare @ChargePerPerson money
declare @NoofPeople int
declare @EventId int
declare @EventTypeId int
declare @PaymentDate datetime
declare @StartDate datetime
declare @PaymentMethodId int
declare @Description varchar(20)
declare @ChequeNo int
declare @CreditCardNo int
declare @CardHoldersName varchar(20)
declare @CreditCardExpiryDate datetime
declare @Balance money

select @EventId = EventId from inserted
select @NoofPeople = NoofPeople from Management.Events where EventId = @EventId
select @EventTypeId = EventTypeId from Management.Events where EventId = @EventId
select @ChargePerPerson = ChargePerPerson from Events.EventTypes where EventTypeId = @EventTypeId
select @PaymentDate = PaymentDate from inserted
select @StartDate = Startdate from Management.Events where EventId = @EventId
select @PaymentMethodId = PaymentMethodId from inserted
select @Description = Description from Management.PaymentMethods where PaymentMethodId = @PaymentMethodId
select @ChequeNo = ChequeNo from inserted
select @CreditCardNo = CreditCardNo from inserted
select @CardHoldersName = CardHoldersName from inserted
select @CreditCardExpiryDate = CreditCardExpiryDate from inserted


if exists(select EventTypeId, EventId from Management.Events where EventTypeId = @EventTypeId and EventId = @EventId)
begin 
	if @PaymentDate <= @StartDate
		begin
		if @Description = 'cash'
			begin
				if @ChequeNo = 0 and @CreditCardNo = 0 and @CardHoldersName = '' and @CreditCardExpiryDate is null
				begin
					set @PaymentAmount = @ChargePerPerson * @NoofPeople
					insert into Management.Payment(EventId, PaymentAmount, PaymentDate, PaymentMethodId, CreditCardExpiryDate, Balance) values(@EventId, @PaymentAmount, @PaymentDate, @PaymentMethodId, @CreditCardExpiryDate, @PaymentAmount)
				end
				else
				begin
					print 'You cant input cheque details and credit card details when payment method is cash'
					rollback
				end
			end
		if @Description = 'cheque'
			begin
				if @ChequeNo != 0
				begin
					if @CreditCardNo = 0 and @CardHoldersName = '' and @CreditCardExpiryDate is null
						begin
							set @PaymentAmount = @ChargePerPerson * @NoofPeople
							insert into Management.Payment(EventId, PaymentAmount, PaymentDate, PaymentMethodId, ChequeNo, Balance) values(@EventId, @PaymentAmount, @PaymentDate, @PaymentMethodId, @ChequeNo, @PaymentAmount)
						end
					else
						begin
						print 'You cant input credit card details when payment method is cheque'
						rollback
						end
				end
				else
				begin
					print 'Cheque No is missing'
				rollback
				end
			end
		if @Description = 'credit card'
			begin
				if @CreditCardNo != 0 and @CardHoldersName != '' and @CreditCardExpiryDate is not null
				begin
					if @ChequeNo = 0 
						begin
							set @PaymentAmount = @ChargePerPerson * @NoofPeople
							insert into Management.Payment(EventId, PaymentAmount, PaymentDate, PaymentMethodId,CreditCardExpiryDate,CardHoldersName,CreditCardNo, Balance) values(@EventId, @PaymentAmount, @PaymentDate, @PaymentMethodId,@CreditCardExpiryDate,@CardHoldersName,@CreditCardNo, @PaymentAmount)
						end
					else
						begin
							print 'You cant input cheque details when payment method is credit card'
							rollback
						end
				end
				else
				begin
				print 'A credit card detail is missing'
				rollback
				end
			end
		end
	else
		begin
			print 'Payment date is greater than the start date of the event'
			rollback
		end
end
else
begin 
	print 'EventId doesnt exist or isnt inserted'
	rollback
end
go


create trigger Payment_Status on Management.PaymentStatus
instead of insert as
declare @AmountPaid money
declare @Balance money
declare @Status varchar(10)
declare @PaymentId int
declare @PaymentAmount money


select @AmountPaid = AmountPaid from inserted
select @PaymentId = PaymentId from inserted 
select @Balance = Balance from Management.payment where PaymentId = @PaymentId
select @PaymentAmount = PaymentAmount from Management.Payment where PaymentId = @PaymentId

if exists(select paymentId from Management.Payment where PaymentId = @PaymentId)
begin
	if @AmountPaid <= @Balance 
	begin
		if @AmountPaid >= (@PaymentAmount / 4)
		begin
			set @Balance = @Balance - @AmountPaid
			if @Balance != 0
			begin
				set @Status = 'pending'
			end
			else
			begin
				set @Status = 'paid'
			end
			update Management.Payment set Balance = @Balance where PaymentId = @PaymentId
			insert into Management.PaymentStatus values(@AmountPaid, @Balance, @Status,@PaymentId)
		end
		else
		begin
			print 'Payment must be greater than 25% of the total amount'
			rollback
		end
	end
	else
	begin
	print 'Amount is greater than balance due'
	rollback
	end
end
else
begin 
	print 'PaymentId doesnt exist or isnt inserted'
rollback
end
go
	

insert into Events.Customers(Name, Address, City, State, Phone) values('Ife', 'West brooke Avenue', 'Lagos', 'Lagos', '12-345-6789-012-098')
go

insert into Events.EventTypes(Description, ChargePerPerson) values('Destination wedding', 20)
go

insert into HumanResources.Employees(FirstName, LastName, Address, Phone, Title) values('Teju', 'Ogunleye', 'No 20 Aderopo strt',
 '33-121-1111-111-111', 'Event Manager')
go

insert into Management.Events(EventName, StartDate, EndDate, Location, NoOfPeople, StaffRequired, EventTypeId, CustomerId, EmployeeId) values(
'Wedding', '2023/11/15', '2023/11/16', 'Agindigbin', 200, 20, 1, 1, 1)
go

insert into Management.PaymentMethods(Description) values('cheque')
go

insert into Management.Payment( PaymentMethodId, PaymentDate) values( 3, '2023/11/13')
go

insert into Management.PaymentStatus(AmountPaid, PaymentId) values(1000, 1)
go

select * from Events.Customers
select * from Events.EventTypes
select * from Management.Events
select * from HumanResources.Employees
select * from Management.Payment
select * from Management.PaymentMethods
select * from Management.PaymentStatus
go

drop database ShowmanHouse


