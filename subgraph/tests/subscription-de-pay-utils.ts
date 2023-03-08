import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  ChangeTrustedForwarder,
  CompanyPendingSet,
  CompanySet,
  CompanyWithdraw,
  DataContractUpdated,
  DepositStatusChanged,
  TreasurySet,
  UserCharged,
  UserDeposit,
  UserWithdraw,
  WithdrawalStatusChanged
} from "../generated/SubscriptionDePay/SubscriptionDePay"

export function createChangeTrustedForwarderEvent(
  trustedForwarder: Address
): ChangeTrustedForwarder {
  let changeTrustedForwarderEvent = changetype<ChangeTrustedForwarder>(
    newMockEvent()
  )

  changeTrustedForwarderEvent.parameters = new Array()

  changeTrustedForwarderEvent.parameters.push(
    new ethereum.EventParam(
      "trustedForwarder",
      ethereum.Value.fromAddress(trustedForwarder)
    )
  )

  return changeTrustedForwarderEvent
}

export function createCompanyPendingSetEvent(
  _company: Address
): CompanyPendingSet {
  let companyPendingSetEvent = changetype<CompanyPendingSet>(newMockEvent())

  companyPendingSetEvent.parameters = new Array()

  companyPendingSetEvent.parameters.push(
    new ethereum.EventParam("_company", ethereum.Value.fromAddress(_company))
  )

  return companyPendingSetEvent
}

export function createCompanySetEvent(_company: Address): CompanySet {
  let companySetEvent = changetype<CompanySet>(newMockEvent())

  companySetEvent.parameters = new Array()

  companySetEvent.parameters.push(
    new ethereum.EventParam("_company", ethereum.Value.fromAddress(_company))
  )

  return companySetEvent
}

export function createCompanyWithdrawEvent(
  token: Address,
  amount: BigInt
): CompanyWithdraw {
  let companyWithdrawEvent = changetype<CompanyWithdraw>(newMockEvent())

  companyWithdrawEvent.parameters = new Array()

  companyWithdrawEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  companyWithdrawEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return companyWithdrawEvent
}

export function createDataContractUpdatedEvent(
  _dataContract: Address
): DataContractUpdated {
  let dataContractUpdatedEvent = changetype<DataContractUpdated>(newMockEvent())

  dataContractUpdatedEvent.parameters = new Array()

  dataContractUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "_dataContract",
      ethereum.Value.fromAddress(_dataContract)
    )
  )

  return dataContractUpdatedEvent
}

export function createDepositStatusChangedEvent(
  _status: boolean
): DepositStatusChanged {
  let depositStatusChangedEvent = changetype<DepositStatusChanged>(
    newMockEvent()
  )

  depositStatusChangedEvent.parameters = new Array()

  depositStatusChangedEvent.parameters.push(
    new ethereum.EventParam("_status", ethereum.Value.fromBoolean(_status))
  )

  return depositStatusChangedEvent
}

export function createTreasurySetEvent(_treasury: Address): TreasurySet {
  let treasurySetEvent = changetype<TreasurySet>(newMockEvent())

  treasurySetEvent.parameters = new Array()

  treasurySetEvent.parameters.push(
    new ethereum.EventParam("_treasury", ethereum.Value.fromAddress(_treasury))
  )

  return treasurySetEvent
}

export function createUserChargedEvent(
  user: Address,
  token: Address,
  fee: BigInt
): UserCharged {
  let userChargedEvent = changetype<UserCharged>(newMockEvent())

  userChargedEvent.parameters = new Array()

  userChargedEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  userChargedEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  userChargedEvent.parameters.push(
    new ethereum.EventParam("fee", ethereum.Value.fromUnsignedBigInt(fee))
  )

  return userChargedEvent
}

export function createUserDepositEvent(
  user: Address,
  token: Address,
  deposit: BigInt
): UserDeposit {
  let userDepositEvent = changetype<UserDeposit>(newMockEvent())

  userDepositEvent.parameters = new Array()

  userDepositEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  userDepositEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  userDepositEvent.parameters.push(
    new ethereum.EventParam(
      "deposit",
      ethereum.Value.fromUnsignedBigInt(deposit)
    )
  )

  return userDepositEvent
}

export function createUserWithdrawEvent(
  user: Address,
  token: Address,
  amount: BigInt
): UserWithdraw {
  let userWithdrawEvent = changetype<UserWithdraw>(newMockEvent())

  userWithdrawEvent.parameters = new Array()

  userWithdrawEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  userWithdrawEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  userWithdrawEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return userWithdrawEvent
}

export function createWithdrawalStatusChangedEvent(
  _status: boolean
): WithdrawalStatusChanged {
  let withdrawalStatusChangedEvent = changetype<WithdrawalStatusChanged>(
    newMockEvent()
  )

  withdrawalStatusChangedEvent.parameters = new Array()

  withdrawalStatusChangedEvent.parameters.push(
    new ethereum.EventParam("_status", ethereum.Value.fromBoolean(_status))
  )

  return withdrawalStatusChangedEvent
}
