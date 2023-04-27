import { BigInt } from "@graphprotocol/graph-ts"
import {
  SubscriptionDePay,
  UserCharged,
  UserDeposit,
  UserWithdraw
} from "../generated/SubscriptionDePay/SubscriptionDePay"
import { User, Deposit, Withdrawal, Charges, Balance } from "../generated/schema"


export function handleUserDeposit(event: UserDeposit): void {
  let eventName = "userDeposit" + "-" + event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let entity = new Deposit(eventName)
  entity.amount = event.params.deposit
  entity.token = event.params.token
  entity.createdAt = event.block.timestamp
  entity.user = event.params.user.toHexString()
  entity.save()

  let user = User.load(event.params.user.toHex())
  if (!user) {
    user = new User(event.params.user.toHex())
    user.id = event.params.user.toHex()
  }
  user.save()

  let balance = Balance.load(event.params.user.toHex() + "-" + event.params.token.toHex())
  if (!balance) {
    balance = new Balance(event.params.user.toHex() + "-" + event.params.token.toHex())
    balance.id = event.params.user.toHex() + "-" + event.params.token.toHex()
    balance.amount = BigInt.fromI32(0)
  }
  balance.token = event.params.token
  balance.user = event.params.user.toHex()
  balance.amount = balance.amount.plus(event.params.deposit)
  balance.save()
}

export function handleUserCharged(event: UserCharged): void {
  let eventName = "userCharged" + "-" + event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let entity = new Charges(eventName)
  entity.amount = event.params.fee
  entity.createdAt = event.block.timestamp
  entity.user = event.params.user.toHexString()
  entity.save()

  let user = User.load(event.params.user.toHex())
  if (!user) {
    user = new User(event.params.user.toHex())
    user.id = event.params.user.toHex()
  }
  user.save()
  let balance = Balance.load(event.params.user.toHex() + "-" + event.params.token.toHex())
  if (!balance) {
    balance = new Balance(event.params.user.toHex() + "-" + event.params.token.toHex())
    balance.id = event.params.user.toHex() + "-" + event.params.token.toHex()
    balance.amount = BigInt.fromI32(0)
  }
  balance.token = event.params.token
  balance.user = event.params.user.toHex()
  balance.amount = balance.amount.minus(event.params.fee)
  balance.save()
}

export function handleUserWithdraw(event: UserWithdraw): void {
  let eventName = "userWithdraw" + "-" + event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let entity = new Withdrawal(eventName)
  entity.amount = event.params.amount
  entity.token = event.params.token
  entity.createdAt = event.block.timestamp
  entity.user = event.params.user.toHexString()
  entity.save()

  let user = User.load(event.params.user.toHex())
  if (!user) {
    user = new User(event.params.user.toHex())
    user.id = event.params.user.toHex()
  }
  user.save()
  let balance = Balance.load(event.params.user.toHex() + "-" + event.params.token.toHex())
  if (!balance) {
    balance = new Balance(event.params.user.toHex() + "-" + event.params.token.toHex())
    balance.id = event.params.user.toHex() + "-" + event.params.token.toHex()
    balance.amount = BigInt.fromI32(0)
  }
  balance.token = event.params.token
  balance.user = event.params.user.toHex()
  balance.amount = balance.amount.minus(event.params.amount)
  balance.save()

}
