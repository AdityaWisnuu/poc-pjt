import { Injectable } from '@nestjs/common';
import { Corridor, ID_BANKS, ID_SAMPLES, SampleAccount } from './corridors';

const pause = (ms: number) => new Promise((done) => setTimeout(done, ms));
const ref = (prefix: string, seed: string) =>
  `${prefix}${seed.replaceAll('-', '').slice(-10).toUpperCase()}`;

export class AccountNotFoundError extends Error {}

function find(samples: SampleAccount[], bank: string, account: string) {
  const digits = account.replace(/\s|-/g, '');
  return samples.find((s) => s.bank === bank && s.account === digits);
}

/**
 * Stands in for Juara Remiten's Bank INA disbursement (SNAP). Response codes
 * follow the SNAP pattern: HTTP status + service code + case (Transfer
 * Interbank is service 18, account inquiry 16).
 */
@Injectable()
export class BankInaSim {
  inquiry(bank: string, account: string) {
    const hit = find(ID_SAMPLES, bank, account);
    if (!hit) throw new AccountNotFoundError('Rekening tidak ditemukan');
    return {
      name: hit.name,
      bankName: ID_BANKS.find((b) => b.code === bank)?.name ?? bank,
      responseCode: '2001600',
    };
  }

  async transferInterbank(partnerReferenceNo: string) {
    await pause(1200);
    return {
      responseCode: '2001800',
      responseMessage: 'Successful',
      referenceNo: ref('BINA', partnerReferenceNo),
      partnerReferenceNo,
      channel: 'BI-FAST',
      transactionDate: new Date().toISOString(),
    };
  }
}

/** Stands in for the licensed partner in the other country. */
@Injectable()
export class PartnerSim {
  inquiry(corridor: Corridor, bank: string, account: string) {
    const hit = find(corridor.samples, bank, account);
    if (!hit)
      throw new AccountNotFoundError('Rekening tidak ditemukan di bank tujuan');
    return {
      name: hit.name,
      bankName: corridor.banks.find((b) => b.code === bank)?.name ?? bank,
    };
  }

  async collect(corridor: Corridor, seed: string) {
    await pause(900);
    return { reference: ref(`${corridor.code}C`, seed) };
  }

  async convert(seed: string) {
    await pause(900);
    return { reference: ref('FX', seed) };
  }

  async payout(corridor: Corridor, seed: string) {
    await pause(1200);
    return {
      reference: ref(`${corridor.code}P`, seed),
      channel: corridor.payoutChannel,
      status: 'PAID',
    };
  }
}
