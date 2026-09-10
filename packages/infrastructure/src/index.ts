export interface TransactionBoundary { run<T>(operation: () => Promise<T>): Promise<T> }
