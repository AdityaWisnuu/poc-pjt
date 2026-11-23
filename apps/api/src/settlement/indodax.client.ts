import { Injectable } from '@nestjs/common';
import { createHmac } from 'node:crypto';
import { request } from 'node:https';
import { AppConfig } from '../config';
import { UnknownOutcomeError } from './gateway';

export class IndodaxRejectedError extends Error {
  constructor(
    readonly status: number,
    readonly code: number | undefined,
    message: string,
  ) {
    super(message);
  }
}

const HOST = 'api.indodax.com';
const USER_AGENT = 'Mozilla/5.0 (compatible; poc-pjt)';

/** Signed Trade API V2 client. All calls leave through the SSH tunnel to the VPS IP. */
@Injectable()
export class IndodaxClient {
  constructor(private readonly config: AppConfig) {}

  get<T>(path: string, params: Record<string, string> = {}) {
    return this.call<T>('GET', path, params);
  }

  /** Sent exactly once. A lost response raises UnknownOutcomeError. */
  post<T>(path: string, params: Record<string, string>) {
    return this.call<T>('POST', path, params);
  }

  private async serverTime(): Promise<number> {
    const response = await fetch('https://indodax.com/api/server_time', {
      headers: { 'User-Agent': USER_AGENT },
      signal: AbortSignal.timeout(6000),
    });
    const body = (await response.json()) as { server_time: number };
    return body.server_time;
  }

  private async call<T>(
    method: 'GET' | 'POST',
    path: string,
    params: Record<string, string>,
  ): Promise<T> {
    const timestamp = await this.serverTime();
    const query = new URLSearchParams({
      ...params,
      timestamp: String(timestamp),
      recvWindow: '5000',
    }).toString();
    const sign = createHmac('sha256', this.config.required('INDODAX_API_SECRET'))
      .update(query)
      .digest('hex');
    const headers: Record<string, string> = {
      Host: HOST,
      'User-Agent': USER_AGENT,
      'X-APIKEY': this.config.required('INDODAX_API_KEY'),
      Sign: sign,
    };
    if (method === 'POST') {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      headers['Content-Length'] = String(Buffer.byteLength(query));
    }

    return new Promise<T>((resolve, reject) => {
      const req = request(
        {
          host: '127.0.0.1',
          port: this.config.tunnelPort,
          servername: HOST,
          method,
          path: method === 'GET' ? `${path}?${query}` : path,
          headers,
          timeout: 20000,
        },
        (res) => {
          const chunks: Buffer[] = [];
          res.on('data', (chunk: Buffer) => chunks.push(chunk));
          res.on('error', () =>
            reject(new UnknownOutcomeError('Respons Indodax terputus')),
          );
          res.on('end', () => {
            const text = Buffer.concat(chunks).toString();
            const status = res.statusCode ?? 0;
            let body: { code?: number; msg?: string } | undefined;
            try {
              body = JSON.parse(text) as { code?: number; msg?: string };
            } catch {
              body = undefined;
            }
            if (status >= 200 && status < 300 && body) {
              resolve(body as T);
            } else if (status >= 400 && status < 500) {
              reject(
                new IndodaxRejectedError(
                  status,
                  body?.code,
                  body?.msg ?? `Indodax menolak (${status})`,
                ),
              );
            } else {
              reject(new UnknownOutcomeError(`Status Indodax ${status}`));
            }
          });
        },
      );
      req.on('timeout', () => req.destroy(new Error('timeout')));
      req.on('error', (error: NodeJS.ErrnoException) => {
        // Nothing was sent if the local tunnel refused the connection.
        if (error.code === 'ECONNREFUSED') {
          reject(new Error('Tunnel Indodax belum aktif'));
        } else {
          reject(new UnknownOutcomeError('Koneksi ke Indodax terputus'));
        }
      });
      if (method === 'POST') req.write(query);
      req.end();
    });
  }
}
